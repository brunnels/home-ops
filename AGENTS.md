# AGENTS.md: AI Agent Guide for home-ops

A Talos-based Kubernetes GitOps infrastructure project managing multiple clusters (kdev/korg) with Flux, Helmfile, and Kustomize.

**📋 Quick Start:**

- **New to this codebase?** Start with the [CHEATSHEET.md](./CHEATSHEET.md) - tables and quick reference
- **Setting up secrets?** See [SECRETS.md](./SECRETS.md) - Akeyless configuration for each cluster
- **Debugging deployments?** See [DEBUGGING.md](./DEBUGGING.md) - detailed troubleshooting workflows
- **Full documentation:** Continue reading this file

## Architecture Overview

**Three-layer infrastructure:**

- **Layer 1 - OS/Cluster**: Talos Linux (talconfig.yaml) → generates kubeconfig via talhelper
- **Layer 2 - Kubernetes**: Kustomize+Flux manages app lifecycle; two clusters in `kubernetes/clusters/{kdev,korg}/`
- **Layer 3 - Apps**: HelmRelease resources deployed by Flux; organized by namespace (database, network, security, etc.)

**Key dependency flow:**

1. Bootstrap phase: `just bootstrap talos|apps kdev|korg` → talhelper generates Talos configs
2. Helmfile deploys foundational apps (Cilium, external-secrets, etc.)
3. Flux GitRepository watches git, reconciles via Kustomization chain: `cluster-settings` → `cluster-secrets` → `cluster-apps`

## Developer Workflows

**Start here:**

```bash
just -l                          # List all tasks
just bootstrap talos kdev        # Bootstrap Talos cluster
just bootstrap apps kdev         # Deploy apps + Flux
just set-cluster kdev            # Switch kubectl context
flux reconcile kustomization -n flux-system flux-system  # Force Flux sync
```

**Critical files for cluster operations:**

- `kubernetes/clusters/kdev/flux/ks.yaml` - Master Kustomization that patches all child Kustomizations with settings/secrets
- `kubernetes/kdev/**/*.yaml` - Per-namespace app declarations (kustomization + HelmRelease resources)
- `talos/kdev/talconfig.yaml` - Node config (IPs, disk, extensions, kernel args)
- `bootstrap/helmfile/apps.yaml` - Bootstrap chart releases (applies before Flux)

**Before committing changes, always render and validate:**

```bash
# Render what will be deployed to verify substitutions are correct
flate -p ./kubernetes/clusters/korg/flux build all > /tmp/korg-rendered.yaml

# Validate syntax and check for unresolved placeholders
grep -i placeholder /tmp/korg-rendered.yaml || echo "✓ All placeholders resolved"
kubectl apply -f /tmp/korg-rendered.yaml --dry-run=client
```

## Configuration Patterns

**Secret Management (Akeyless vault integration):**

- Secrets stored in Akeyless: `ak://<vault_path>/<json_key>`
- `scripts/akeyless.sh` parses stdin, replaces tokens with Akeyless values via jq
- Bootstrap flow: `envsubst` → `akeyless.sh` → `kubectl apply`
- Example: `cluster-secrets.yaml` uses `ak://${VAULT_PREFIX}-cluster/SECRET_DOMAIN`

**Kustomization composition pattern (critical for changes):**

- Cluster-specific kustomizations (e.g., `kdev/default/kustomization.yaml`) use components:
    - `../../clusters/kdev` (Component with cluster-settings ConfigMap)
    - `../../components/common` (shared repos, cluster-secrets resources)
    - `replacements` patch to apply settings substitution (targetNamespace, retryInterval, timeout, etc.)
- Parent Kustomization (flux/ks.yaml) injects `cluster-settings` ConfigMap and `cluster-secrets` Secret into all children via patches

**App deployment pattern (HelmRelease defaults):**

- All HelmRelease resources patched with defaults (install.crds, rollback, upgrade strategies)
- Set annotation `fluxcd.io/settings-substitutions: disabled` to skip settings injection
- Set annotation `fluxcd.io/helm-release-defaults: disabled` to skip default patches

## Project-Specific Conventions

- **Namespace organization**: One directory per namespace under `kubernetes/{kdev,korg}/` and `kubernetes/base/`
- **Two-cluster model**: Changes usually needed in both `kdev/` (dev) and `korg/` (prod) copies
- **Just commands** = primary interface; grouped by `[group('')]` attribute
- **No plain Pods/Deployments**: Everything uses HelmRelease (via Helm charts or local charts in `charts/`)
- **All resources server-side applied** (`--server-side`) to handle large manifests
- **Age encryption**: SOPS encrypts `*.sops.yaml` files; key at `age.key`
- **Tool versions pinned in `.mise.toml`**: Use `mise install` to get exact versions; tools include `flate` (Flux renderer), `talhelper`, `flux2`, `helm`, `helmfile`, `kustomize`, etc.

## Making Changes

1. **Adding an app**:
    - Create `kubernetes/base/namespace/app/` with kustomization + HelmRelease
    - Reference in both `kubernetes/kdev/namespace/kustomization.yaml` and `kubernetes/korg/` (unless cluster-specific)

2. **Modifying Talos config**:
    - Edit `talos/kdev/talconfig.yaml` or `talos/korg/talconfig.yaml`
    - `just talos generate-config kdev` → `talhelper genconfig`
    - `just talos apply-node <ip> kdev` to apply to nodes

3. **Adding secrets**:
    - See [SECRETS.md](./SECRETS.md) for complete list of required secrets per cluster
    - Store in Akeyless at path matching `ak://${VAULT_PREFIX}-cluster/KEY_NAME` (VAULT_PREFIX = cluster name)
    - Reference via `ak://kdev-cluster/KEY_NAME` in manifests; akeyless.sh expands before apply

4. **Flux reconciliation troubleshooting**:
    - `kubectl -n flux-system logs -f deployment/kustomize-controller`
    - `kubectl -n flux-system logs -f deployment/helm-controller`
    - Check Kustomization status: `kubectl describe ks -n flux-system`

5. **Fetching external resources from GitHub**:
    - `just yoink <GITHUB_URL>` - Downloads files/directories from GitHub repos (uses `fetcher.py`)
    - Example: `just yoink https://github.com/owner/repo/tree/main/path/to/dir`

## Integration Points

- **Akeyless**: Injected as ExternalSecret operator; ClusterSecretStore at `kubernetes/base/external-secrets-stores/akeyless/`
- **Helmfile**: CRD templates + bootstrap releases; schemas at `bootstrap/helmfile/templates/release.yaml.gotmpl`
- **Cilium CNI**: Deployed via helmfile, networks defined in `kubernetes/base/kube-system/cilium/networks.yaml`
- **Weave GitOps**: Web UI for Flux, deployed to `flux-system` namespace with OIDC auth
- **cert-manager**: Manages TLS certs, integrates with Cloudflare for DNS validation
- **flate**: Tool for rendering complete Kustomize manifests without applying; essential for validation before commits

## File Structure Quick Reference

```
bootstrap/         # Bootstrap phase: secrets, helmfile, initial apps
kubernetes/
  base/            # Shared resources (kustomization bases per namespace)
  common/          # Common components (cluster-secrets, repos)
  components/      # Kustomize components for reuse
    common/        # Shared across all clusters (alerts, cluster-secrets, HelmChart repos)
    replacements/  # Kustomization replacements (injects namespace, retryInterval, timeout, etc.)
    intel-gpu/     # Intel GPU device plugin and ResourceClaim template
    igpu-spread/   # Pod spreading rules for integrated GPU workloads
    envoy-gateway-oidc/  # OIDC configuration for Envoy Gateway
    pgo-db-init/   # PostgreSQL Operator database initialization
    dragonfly-cluster/   # Dragonfly (Redis alternative) multi-node cluster setup
    theme-park/    # Theme Park Envoy extension for unified app theming
    volsync/       # VolSync replication sources/destinations
    kopiur/        # Backup/restore component (snapshots, S3 integration)
    zeroscaler/    # Zeroscaler for resource optimization
  clusters/        # Cluster-specific components + Kustomization chains
    kdev/
      flux/        # Master Kustomization defining cluster-settings, cluster-secrets, cluster-apps chain
      cluster-settings/  # ConfigMap with cluster-specific values
    korg/          # Same structure for production cluster
  kdev/, korg/     # Cluster apps by namespace (default, network, database, etc.)
talos/kdev|korg/   # Talos config per cluster
scripts/           # Operational scripts (akeyless.sh, cert renewal, fetcher.py, etc.)
.agents/           # AI agent configurations and instructions
```

## Validation & Debugging Tools

**See [DEBUGGING.md](./DEBUGGING.md) for detailed troubleshooting workflows, Kustomization chain debugging, and common issues.**

**Rendering & inspecting what will be deployed:**

- `flate -p ./kubernetes/clusters/korg/flux build all` - Build + render entire deployment for korg cluster (outputs complete YAML manifest)
- `flate -p ./kubernetes/clusters/kdev/flux build all` - Same for kdev cluster
- `flate -p ./kubernetes/clusters/CLUSTER/flux build KUSTOMIZATION` - Render specific Kustomization (e.g., `cluster-apps`)

**Validating changes before committing:**

- Render output to file: `flate -p ./kubernetes/clusters/korg/flux build all > /tmp/korg-rendered.yaml`
- Check for placeholder substitutions: `grep -i placeholder /tmp/korg-rendered.yaml` (should be empty if all substitutions resolved)
- Validate YAML syntax: `kubectl apply -f /tmp/korg-rendered.yaml --dry-run=client` (dry-run validates without applying)

**Understanding the Kustomization build chain:**

- Master Kustomization: `kubernetes/clusters/kdev/flux/ks.yaml` defines three sequential Kustomizations:
    1. **cluster-settings** - Loads cluster-settings ConfigMap from `kubernetes/clusters/kdev/cluster-settings/`
    2. **cluster-secrets** - Applies cluster-secrets Secret from `kubernetes/components/common/cluster-secrets/`
    3. **cluster-apps** - Main reconciliation that patches all child Kustomizations with settings/secrets
- Each namespace-level Kustomization (e.g., `kubernetes/kdev/default/kustomization.yaml`):
    - Includes components: `../../clusters/kdev` + `../../components/common`
    - Uses `replacements` to substitute settings into HelmRelease resources
    - Gets patched by parent with substituteFrom for settings/secrets injection

**Debugging Flux reconciliation:**

- Watch Flux logs: `kubectl -n flux-system logs -f deployment/kustomize-controller` (shows Kustomization builds)
- Watch Helm controller: `kubectl -n flux-system logs -f deployment/helm-controller` (shows HelmRelease status)
- Check Kustomization status: `kubectl describe kustomization cluster-apps -n flux-system` (shows conditions/errors)
- Get GitRepository status: `kubectl describe gitrepository flux-system -n flux-system` (shows git sync state)

**Common issues:**

- **PlaceHolder values not substituted**: Missing cluster-settings ConfigMap or cluster-secrets Secret in substituteFrom
- **HelmRelease stuck/pending**: Check `helm list -n NAMESPACE`, look for failed releases via `helm history RELEASE -n NAMESPACE`
- **CRD conflicts**: Run with `--force-conflicts` flag; Flux kustomize-controller applies with this by default
- **Stale resources**: Set `deletionPolicy: WaitForTermination` on parent Kustomization to handle cleanup ordering

## Command Reference

- `just bootstrap talos CLUSTER` - Generate + apply Talos config, fetch kubeconfig
- `just bootstrap apps CLUSTER` - Deploy CRDs, helmfile, resources, then Flux takes over
- `just kube reconcile CLUSTER` - Force Flux reconciliation (GitRepository + all Kustomizations)
- `just talos generate-config CLUSTER` - Regenerate Talos manifests from talconfig
- `just talos reset-node IP CLUSTER` - Reset single node to maintenance mode (DESTRUCTIVE)
- `flate -p ./kubernetes/clusters/CLUSTER/flux build all` - Render complete deployment for validation
- `just yoink URL [DEST]` - Fetch files/directories from GitHub repository URL (uses fetcher.py)
- `just set-cluster CLUSTER` - Switch kubectl context to specified cluster
