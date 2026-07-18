# Home Operations

A personal Kubernetes GitOps infrastructure project using Talos Linux, Flux, and Helmfile to manage multiple clusters (development and production) with declarative configuration, automated deployments, and comprehensive secret management via Akeyless.

**Status:** Active multi-cluster infrastructure • **Clusters:** kdev (development) + korg (production)

## 📊 Cluster Status

### kdev (Development)

![Talos](https://kromgo.kraven.dev/badges/talos_version)
![Kubernetes](https://kromgo.kraven.dev/badges/kubernetes_version)
![Flux](https://kromgo.kraven.dev/badges/flux_version)
![Nodes](https://kromgo.kraven.dev/badges/cluster_node_count)
![Pods](https://kromgo.kraven.dev/badges/cluster_pod_count)
![CPU](https://kromgo.kraven.dev/badges/cluster_cpu_usage)
![Memory](https://kromgo.kraven.dev/badges/cluster_memory_usage)
![Uptime](https://kromgo.kraven.dev/badges/cluster_uptime_age)
![Alerts](https://kromgo.kraven.dev/badges/cluster_alert_count)

[View kdev Status Dashboard](https://status.kraven.dev/)

### korg (Production)

![Talos](https://kromgo.kraven.org/badges/talos_version)
![Kubernetes](https://kromgo.kraven.org/badges/kubernetes_version)
![Flux](https://kromgo.kraven.org/badges/flux_version)
![Nodes](https://kromgo.kraven.org/badges/cluster_node_count)
![Pods](https://kromgo.kraven.org/badges/cluster_pod_count)
![CPU](https://kromgo.kraven.org/badges/cluster_cpu_usage)
![Memory](https://kromgo.kraven.org/badges/cluster_memory_usage)
![Uptime](https://kromgo.kraven.org/badges/cluster_uptime_age)
![Alerts](https://kromgo.kraven.org/badges/cluster_alert_count)

[View korg Status Dashboard](https://status.kraven.org/)

## 🏗️ Quick Overview

This project implements a three-layer infrastructure:

1. **OS/Cluster Layer** - [Talos Linux](https://www.talos.dev/) for immutable, declarative cluster provisioning
2. **Kubernetes Layer** - Flux CD with Kustomize for GitOps app deployment; two independent clusters
3. **Application Layer** - HelmRelease resources organized by namespace (database, network, media, observability, etc.)

**Git-driven workflow:** Push changes to git → Flux reconciles → Apps deployed automatically

## 📚 Documentation Guide

Start here based on your role:

### 👤 For Developers & Operators

- **[CHEATSHEET.md](./CHEATSHEET.md)** - Quick command reference, symptom/solution table, essential workflows
- **[AGENTS.md](./AGENTS.md)** - Complete architecture guide, patterns, and conventions
- **[SECRETS.md](./SECRETS.md)** - All required Akeyless secrets per cluster + creation guide
- **[DEBUGGING.md](./DEBUGGING.md)** - Troubleshooting workflows, common issues, validation tools

### 🤖 For AI Agents & Automation

- **[AGENTS.md](./AGENTS.md)** - Designed for AI coding agents with codebase patterns and workflows
- **[CHEATSHEET.md](./CHEATSHEET.md)** - Tables and quick reference for fast lookups
- **[SECRETS.md](./SECRETS.md)** - Complete secret inventory with required keys
- **[DEBUGGING.md](./DEBUGGING.md)** - Diagnostic workflows using `flate` rendering tool

## 🚀 Quick Start

### Prerequisites

- `talhelper` - Talos config generation
- `flux` - Flux CLI for reconciliation
- `kubectl` - Kubernetes CLI
- `helm` - Helm package manager
- `flate` - Kustomize renderer (for validation)
- `akeyless` - Akeyless CLI (for secrets)
- `just` - Task runner

### Bootstrap a Cluster

```bash
# 1. Generate & apply Talos OS configuration
just bootstrap talos kdev

# 2. Deploy Kubernetes apps & Flux
just bootstrap apps kdev

# 3. Switch kubectl context
just set-cluster kdev

# 4. Verify Flux is running
flux check --pre
```

### Common Commands

| Task                               | Command                                                                 |
| ---------------------------------- | ----------------------------------------------------------------------- |
| **List all tasks**                 | `just -l`                                                               |
| **Force Flux reconciliation**      | `flux reconcile kustomization -n flux-system flux-system --with-source` |
| **Render full deployment**         | `flate -p ./kubernetes/clusters/korg/flux build all`                    |
| **Check Flux status**              | `kubectl describe kustomization cluster-apps -n flux-system`            |
| **View Kustomize controller logs** | `kubectl -n flux-system logs -f deployment/kustomize-controller`        |
| **Check app deployment**           | `kubectl describe helmrelease NAME -n NAMESPACE`                        |

See **[CHEATSHEET.md](./CHEATSHEET.md)** for more commands and troubleshooting.

## 📁 Directory Structure

```
home-ops/
├─ bootstrap/              # Bootstrap phase (CRDs, Helmfile, initial resources)
│  ├─ helmfile/           # Cilium, external-secrets, and core apps
│  ├─ cluster-secrets.yaml    # Secret template with Akeyless token substitution
│  └─ akeyless.yaml       # Akeyless credentials
│
├─ kubernetes/            # GitOps app deployment
│  ├─ base/               # Shared app definitions (kustomization bases)
│  ├─ components/         # Reusable Kustomize components (OIDC, backups, etc.)
│  ├─ clusters/           # Cluster-specific Kustomization chain
│  │  ├─ kdev/flux/ks.yaml    # Master Kustomization (patches all children)
│  │  └─ korg/flux/ks.yaml    # Master Kustomization (patches all children)
│  ├─ kdev/               # Per-namespace app definitions for kdev cluster
│  └─ korg/               # Per-namespace app definitions for korg cluster
│
├─ talos/                 # Talos OS configuration
│  ├─ kdev/
│  │  ├─ talconfig.yaml   # Node config (IPs, disk, extensions, kernel args)
│  │  └─ talsecret.sops.yaml  # Encrypted Talos secrets
│  └─ korg/
│
├─ scripts/               # Operational scripts
│  └─ akeyless.sh         # Token replacement engine (ak:// → actual value)
│
├─ charts/                # Custom Helm charts (pod-gateway, vpn-gateway)
├─ justfile               # Task automation (see `just -l`)
├─ AGENTS.md              # AI agent guide (architecture, patterns)
├─ SECRETS.md             # All required Akeyless secrets per cluster
├─ CHEATSHEET.md          # Quick reference tables & commands
├─ DEBUGGING.md           # Troubleshooting workflows & common issues
└─ README.md              # This file
```

## 🔑 Key Concepts

### Two-Cluster Model

- **kdev** - Development cluster for testing changes
- **korg** - Production cluster for stable deployments
- **Strategy:** Changes created in `kubernetes/base/`, referenced in both `kdev/` and `korg/`

### Secret Management (Akeyless)

- Secrets stored in Akeyless vault: `ak://<vault_path>/<json_key>`
- `scripts/akeyless.sh` replaces tokens during bootstrap
- Pattern: `ak://${VAULT_PREFIX}-cluster/SECRET_DOMAIN` → actual value
- Each cluster has its own VAULT_PREFIX (kdev/korg)

### GitOps Reconciliation Chain

```
1. cluster-settings Kustomization
   ↓ (loads ConfigMap with cluster-wide settings)
2. cluster-secrets Kustomization
   ↓ (loads Secret from Akeyless via ExternalSecret)
3. cluster-apps Kustomization
   └─ Patches all child Kustomizations with settings/secrets
      └─ Reconciles all apps in kubernetes/kdev/ or kubernetes/korg/
```

### Kustomization Pattern

Each namespace Kustomization (e.g., `kdev/default/kustomization.yaml`):

- Includes components: `../../clusters/kdev` (cluster-specific) + `../../components/common` (shared)
- Uses `replacements` to substitute settings into HelmRelease resources
- Gets patched by parent with `substituteFrom` for settings/secrets injection

### HelmRelease Defaults

All HelmRelease resources are patched with defaults:

- Install CRDs: `CreateReplace` strategy
- Upgrade strategy: `RemediateOnFailure` with automatic retries
- Disable with annotation: `fluxcd.io/helm-release-defaults: disabled`

## 🔧 Making Changes

### Adding a New Application

1. **Create app definition in base:**

    ```bash
    mkdir -p kubernetes/base/NAMESPACE/APP
    ```

2. **Create Kustomization + HelmRelease:**

    ```yaml
    # kubernetes/base/NAMESPACE/APP/kustomization.yaml
    apiVersion: kustomize.config.k8s.io/v1beta1
    kind: Kustomization
    namespace: NAMESPACE
    components:
        - ../../clusters/kdev # cluster-specific component
        - ../../components/common # shared component
    resources:
        - ./helmrelease.yaml
    ```

3. **Reference in both clusters:**

    ```yaml
    # kubernetes/kdev/NAMESPACE/kustomization.yaml
    resources:
        - ../../base/NAMESPACE/APP

    # kubernetes/korg/NAMESPACE/kustomization.yaml
    resources:
        - ../../base/NAMESPACE/APP
    ```

4. **Validate before pushing:**
    ```bash
    flate -p ./kubernetes/clusters/korg/flux build all > /tmp/rendered.yaml
    grep -i placeholder /tmp/rendered.yaml  # Should be empty
    kubectl apply -f /tmp/rendered.yaml --dry-run=client
    ```

### Setting Up Cluster Secrets

See **[SECRETS.md](./SECRETS.md)** for complete list. Quick example:

```bash
# Create a secret in Akeyless
akeyless create-secret \
  --name "kdev/cloudflare" \
  --secret-value '{"CF_API_TOKEN":"token123","CF_ZONE_ID":"zone456"}'

# Secret is automatically fetched by ExternalSecret during bootstrap
```

### Modifying Talos Configuration

1. Edit `talos/kdev/talconfig.yaml` or `talos/korg/talconfig.yaml`
2. Generate new Talos manifests: `just talos generate-config kdev`
3. Apply to nodes: `just talos apply-node <IP> kdev`
4. Bootstrap cluster: `just talos upgrade-k8s kdev`

## 🐛 Troubleshooting

### Seeing `...PLACEHOLDER_...` in rendered output?

- Secret missing in Akeyless (see **[SECRETS.md](./SECRETS.md)**)
- Missing ConfigMap/Secret in cluster
- **Solution:** `kubectl get configmap cluster-settings -n flux-system -o yaml`

### HelmRelease stuck in Pending?

- Check Helm status: `helm list -n NAMESPACE`
- View errors: `helm status RELEASE_NAME -n NAMESPACE`
- Tail logs: `kubectl -n flux-system logs -f deployment/helm-controller`

### Kustomization reconciliation failing?

- Render to check for issues: `flate -p ./kubernetes/clusters/korg/flux build all`
- Check status: `kubectl describe kustomization cluster-apps -n flux-system`
- See full troubleshooting guide in **[DEBUGGING.md](./DEBUGGING.md)**

### Resources not being deleted after removal from git?

- Set `deletionPolicy: WaitForTermination` on parent Kustomization
- Force prune: `flux reconcile kustomization cluster-apps -n flux-system --with-source`

**For more issues, see [DEBUGGING.md](./DEBUGGING.md)** - comprehensive troubleshooting workflows.

## 🔗 Integration Points

- **Cilium CNI** - Container networking, deployed via Helmfile before Flux takes over
- **External Secrets** - Pulls secrets from Akeyless ClusterSecretStore
- **cert-manager** - TLS certificate management, integrates with Cloudflare for DNS validation
- **Flux CD** - GitOps orchestration, reconciles every 1 hour (or on git push)
- **Weave GitOps** - Web UI for Flux, deployed to `flux-system` namespace with OIDC auth
- **PostgreSQL Operator (PGO)** - Database management with automated backups
- **Rook Ceph** - Distributed storage for persistent volumes
- **Kopiur** - Backup & restore automation for databases

## 📋 Useful Commands

### Flux & GitOps

```bash
flux check --pre                    # Pre-flight checks
flux reconcile source git flux-system -n flux-system  # Force git sync
flux reconcile kustomization cluster-apps -n flux-system  # Force app sync
kubectl get kustomization -n flux-system   # List all Kustomizations
kubectl get helmrelease -A         # List all HelmReleases
```

### Validation & Rendering

```bash
# Render complete deployment for validation
flate -p ./kubernetes/clusters/korg/flux build all > /tmp/korg.yaml

# Check for unresolved placeholders
grep -i placeholder /tmp/korg.yaml

# Validate YAML syntax (dry-run)
kubectl apply -f /tmp/korg.yaml --dry-run=client
```

### Troubleshooting

```bash
kubectl -n flux-system logs -f deployment/kustomize-controller
kubectl -n flux-system logs -f deployment/helm-controller
kubectl describe kustomization cluster-apps -n flux-system
kubectl describe helmrelease NAME -n NAMESPACE
```

### Talos Management

```bash
just talos generate-config kdev    # Regenerate Talos manifests
just talos apply-node <IP> kdev    # Apply config to node
just talos upgrade-k8s kdev        # Upgrade Kubernetes
just talos reset-node <IP> kdev    # Reset node to maintenance mode (DESTRUCTIVE)
```

## 🛠️ Development Workflow

1. **Create feature in base:** Add app/change in `kubernetes/base/`
2. **Test in kdev:** Reference from `kubernetes/kdev/`
3. **Validate:** `flate -p ./kubernetes/clusters/kdev/flux build all`
4. **Apply to korg:** Reference from `kubernetes/korg/`
5. **Commit to git:** `git add . && git commit && git push`
6. **Flux reconciles:** Within 1 hour or on webhook trigger

## 📖 Documentation Structure

| Document          | Purpose                                     | Audience              |
| ----------------- | ------------------------------------------- | --------------------- |
| **AGENTS.md**     | Architecture, patterns, developer workflows | Developers, AI agents |
| **SECRETS.md**    | Akeyless secrets inventory & creation       | DevOps, bootstrapping |
| **DEBUGGING.md**  | Troubleshooting workflows & tools           | Support, debugging    |
| **CHEATSHEET.md** | Quick command reference & tables            | Everyone              |
| **README.md**     | Project overview & getting started          | New users             |

## ✨ What's Included

### Core Infrastructure

- Talos Linux clusters (immutable OS)
- Flux CD for GitOps reconciliation
- Kustomize for configuration management
- Helmfile for bootstrap phase

### Networking

- Cilium CNI with L7 policies
- Cloudflare Tunnel for ingress
- cert-manager for TLS
- Envoy Gateway for load balancing

### Storage

- Rook Ceph for distributed storage
- OpenEBS LocalPV for local volumes
- Kopia for backup/restore
- VolSync for volume replication

### Observability

- Prometheus for metrics
- Grafana for dashboards
- Loki for log aggregation

### Applications

- PostgreSQL Operator (PGO)
- Media stack (Plex, Sonarr, Radarr, etc.)
- Download managers (SABnzbd, Prowlarr)
- LLM stack (Open WebUI, vLLM)
- And more!

## 🤝 Contributing

When making changes:

1. Test in kdev first
2. Validate with `flate` before committing
3. Reference new secrets in [SECRETS.md](./SECRETS.md) if needed
4. Update documentation if changing architecture
5. Push to git and let Flux reconcile

## 📞 Support & Issues

- **Troubleshooting:** See [DEBUGGING.md](./DEBUGGING.md)
- **Commands:** See [CHEATSHEET.md](./CHEATSHEET.md)
- **Architecture:** See [AGENTS.md](./AGENTS.md)
- **Secrets:** See [SECRETS.md](./SECRETS.md)

## 📝 License

Personal project - not licensed for distribution

---

**Last Updated:** July 2026
