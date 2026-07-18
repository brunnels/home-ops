# Quick Reference: home-ops Agent Cheat Sheet

**Essential Files & Commands**

| Task                            | Command/File                                                     |
| ------------------------------- | ---------------------------------------------------------------- |
| **List all tasks**              | `just -l`                                                        |
| **View all required secrets**   | [SECRETS.md](./SECRETS.md)                                       |
| **Render full korg deployment** | `flate -p ./kubernetes/clusters/korg/flux build all`             |
| **Render full kdev deployment** | `flate -p ./kubernetes/clusters/kdev/flux build all`             |
| **Force Flux sync**             | `flux reconcile kustomization -n flux-system flux-system`        |
| **Watch Kustomize controller**  | `kubectl -n flux-system logs -f deployment/kustomize-controller` |
| **Watch Helm controller**       | `kubectl -n flux-system logs -f deployment/helm-controller`      |
| **Check Kustomization status**  | `kubectl describe kustomization cluster-apps -n flux-system`     |
| **Generate Talos config**       | `just talos generate-config kdev`                                |
| **Bootstrap Talos cluster**     | `just bootstrap talos kdev`                                      |
| **Bootstrap apps + Flux**       | `just bootstrap apps kdev`                                       |

**Key Patterns**

| Pattern                  | Location                                     | Purpose                                                |
| ------------------------ | -------------------------------------------- | ------------------------------------------------------ |
| **Master Kustomization** | `kubernetes/clusters/kdev/flux/ks.yaml`      | Patches all child Kustomizations with settings/secrets |
| **Cluster settings**     | `kubernetes/clusters/kdev/cluster-settings/` | ConfigMap with cluster-specific values                 |
| **Common components**    | `kubernetes/components/common/`              | Shared repos, cluster-secrets                          |
| **Per-namespace apps**   | `kubernetes/kdev/NAMESPACE/`                 | HelmRelease definitions by namespace                   |
| **Akeyless secrets**     | `bootstrap/cluster-secrets.yaml`             | Token format: `ak://VAULT_PREFIX-cluster/KEY`          |
| **Base resources**       | `kubernetes/base/NAMESPACE/`                 | Shared app definitions                                 |

**Troubleshooting Flow**

```
Issue → Check What Should Deploy → Compare to Actual → Examine Logs
   ↓           ↓                      ↓                    ↓
  ???      flate cmd              kubectl get         grep logs
           grep output            diff compare        tail -f
           placeholder check      describe status     describe status
```

**Common Symptoms & Solutions**

| Symptom                               | Check                                                       | Solution                                                                 |
| ------------------------------------- | ----------------------------------------------------------- | ------------------------------------------------------------------------ |
| `...PLACEHOLDER_...` in rendered YAML | Missing ConfigMap/Secret                                    | `kubectl get configmap/secret cluster-{settings,secrets} -n flux-system` |
| HelmRelease stuck "Pending"           | `helm list -n NAMESPACE`                                    | `flux reconcile helmrelease NAME -n NAMESPACE` or check helm errors      |
| "CRD already exists" error            | Kustomize logs                                              | Flux auto-applies with `--force-conflicts` (should work)                 |
| Resources not deleted                 | Kustomization `prune:` setting                              | Set `deletionPolicy: WaitForTermination` in parent                       |
| GitRepository not syncing             | `kubectl describe gitrepository flux-system -n flux-system` | `flux reconcile source git flux-system`                                  |
| Namespace not created                 | `kubectl get namespace`                                     | `kubectl create namespace NAME`                                          |

**File Organization**

```
kubernetes/
├─ base/              ← Shared app definitions (base charts)
├─ components/        ← Reusable Kustomize components
├─ clusters/
│  ├─ kdev/          ← cluster-specific Component + flux/ks.yaml
│  └─ korg/          ← cluster-specific Component + flux/ks.yaml
├─ kdev/             ← Per-namespace Kustomizations (references base + clusters)
└─ korg/             ← Per-namespace Kustomizations (references base + clusters)
```

**Two-Cluster Sync Pattern**

When adding/modifying apps:

1. Create in `kubernetes/base/NAMESPACE/APP/` (one copy, shared)
2. Add/update reference in `kubernetes/kdev/NAMESPACE/kustomization.yaml`
3. Add/update reference in `kubernetes/korg/NAMESPACE/kustomization.yaml`
4. Render both: `flate -p ./kubernetes/clusters/{kdev,korg}/flux build all > /tmp/cluster.yaml`
5. Verify no placeholders: `grep -i placeholder /tmp/cluster.yaml`

**Secret Workflow**

```
Akeyless Secret (e.g., "kdev-cluster/DB_PASSWORD")
  ↓
Reference in YAML: ak://kdev-cluster/DB_PASSWORD
  ↓
bootstrap/cluster-secrets.yaml uses envsubst + akeyless.sh
  ↓
Result: Secret in cluster with actual value
```

**Kustomization Reconciliation Order**

```
1. cluster-settings Kustomization (creates ConfigMap)
   ↓ (depends on)
2. cluster-secrets Kustomization (uses ConfigMap via substituteFrom)
   ↓ (depends on)
3. cluster-apps Kustomization (patches all children)
   ├─ Applies settings/secrets to all child Kustomizations
   ├─ Applies HelmRelease defaults
   └─ Reconciles all apps in kubernetes/kdev
```

**Validation Before Committing**

```bash
# Quick check
flate -p ./kubernetes/clusters/korg/flux build all | grep -i placeholder || echo "✓ OK"

# Full validation
flate -p ./kubernetes/clusters/korg/flux build all > /tmp/rendered.yaml
kubectl apply -f /tmp/rendered.yaml --dry-run=client
echo "✓ No syntax errors"
```

**Documentation**

- **AGENTS.md** (this file) - Architecture, patterns, developer workflows
- **DEBUGGING.md** - Detailed troubleshooting, Kustomization chains, common issues
- **justfile** - All `just` tasks (run `just -l` to see)
- **kubernetes/clusters/kdev/flux/ks.yaml** - Master Kustomization definition

**Pro Tips**

1. Always render before pushing: `flate -p ./kubernetes/clusters/CLUSTER/flux build all > check.yaml`
2. Check for placeholders after every significant change
3. Use `--dry-run=client` to validate before Flux picks up changes
4. `WaitForTermination` deletion policy prevents orphaned resources
5. HelmRelease defaults are critical - don't disable unless you know why
6. Each namespace Kustomization needs BOTH component includes (clusters + common)
7. Use annotations to skip patches for exceptional resources
