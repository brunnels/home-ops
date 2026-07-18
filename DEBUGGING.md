# Debugging & Validation Guide for home-ops

Reference guide for AI agents and developers debugging deployments, validating changes, and troubleshooting Flux reconciliation issues.

**See also:** [SECRETS.md](./SECRETS.md) - Complete list of required Akeyless secrets for each cluster

## Quick Diagnosis Workflow

When something isn't deploying as expected:

```bash
# 1. Render what SHOULD be deployed (baseline truth)
flate -p ./kubernetes/clusters/korg/flux build all > /tmp/korg-rendered.yaml

# 2. Check for unresolved placeholders
grep -i placeholder /tmp/korg-rendered.yaml || echo "✓ All placeholders resolved"

# 3. Validate syntax
kubectl apply -f /tmp/korg-rendered.yaml --dry-run=client

# 4. Compare to what IS deployed
kubectl get all -A -o yaml > /tmp/korg-actual.yaml
diff -u /tmp/korg-rendered.yaml /tmp/korg-actual.yaml | head -100

# 5. Check Flux status
kubectl describe kustomization cluster-apps -n flux-system
kubectl describe gitrepository flux-system -n flux-system

# 6. Tail logs
kubectl -n flux-system logs -f deployment/kustomize-controller
```

## Flate Command Reference

**Tool**: `flate` - Flux Kustomize build renderer (renders complete manifests without applying)

**Basic usage:**

```bash
flate -p PATH build TARGET
```

**Common commands:**

```bash
# Full cluster build
flate -p ./kubernetes/clusters/korg/flux build all

# Specific Kustomization
flate -p ./kubernetes/clusters/korg/flux build cluster-apps

# View only specific resources
flate -p ./kubernetes/clusters/korg/flux build all | grep "kind: HelmRelease"

# Get just the metadata (kind/name)
flate -p ./kubernetes/clusters/korg/flux build all | grep -E "^apiVersion:|^kind:|^  name:"

# Build and save
flate -p ./kubernetes/clusters/korg/flux build all > rendered.yaml

# Pretty print with jq (extract specific resources)
flate -p ./kubernetes/clusters/korg/flux build all | jq 'select(.kind == "Deployment")'
```

## Understanding Placeholder Substitution

**Pattern**: `...PLACEHOLDER_NAME...` appears in rendered output when substitution failed.

**Common placeholders in this codebase:**

- `...PLACEHOLDER_SECRET_DOMAIN...` - Should be substituted from cluster-settings ConfigMap
- `...PLACEHOLDER_VAULT_PREFIX...` - Cluster prefix (kdev/korg) for Akeyless paths
- Any `${VARIABLE}` patterns not substituted by Kustomize

**Why substitution fails:**

1. **Missing Secret in Akeyless**: Required secret not created (see [SECRETS.md](./SECRETS.md))
2. **Missing ConfigMap**: `cluster-settings` not found in flux-system namespace
3. **Missing Secret**: `cluster-secrets` not found or not applied before cluster-apps Kustomization
4. **Substitution disabled**: Kustomization has `fluxcd.io/settings-substitutions: disabled` annotation
5. **Typo in reference**: Kustomization refers to wrong ConfigMap/Secret name

**Fixing:**

```bash
# Verify cluster-settings exists and has data
kubectl get configmap cluster-settings -n flux-system -o yaml | head -20

# Verify cluster-secrets exists
kubectl get secret cluster-secrets -n flux-system -o yaml | head -20

# Force reconciliation to apply missing resources
flux reconcile kustomization cluster-settings -n flux-system
flux reconcile kustomization cluster-secrets -n flux-system
flux reconcile kustomization cluster-apps -n flux-system
```

## Kustomization Build Chain Debugging

**Flow for korg cluster:**

```
flux/ks.yaml (Master - patches children)
  ├─ cluster-settings Kustomization (loads ConfigMap)
  │   └─ path: kubernetes/clusters/korg/cluster-settings
  │       └─ cluster-settings.yaml (ConfigMap resource)
  │
  ├─ cluster-secrets Kustomization (loads Secret)
  │   ├─ path: kubernetes/components/common/cluster-secrets
  │   ├─ dependsOn: cluster-settings
  │   └─ substituteFrom: cluster-settings ConfigMap
  │
  └─ cluster-apps Kustomization (reconciles all apps)
      ├─ path: kubernetes/korg
      ├─ dependsOn: cluster-secrets
      ├─ patches: adds substituteFrom for all child Kustomizations
      └─ patches: adds HelmRelease defaults to all HelmReleases
          ├─ install.crds: CreateReplace
          ├─ upgrade.crds: CreateReplace
          └─ upgrade remediation with retries
```

**Debug at each level:**

```bash
# 1. Check cluster-settings Kustomization
kubectl describe kustomization cluster-settings -n flux-system
kubectl get configmap cluster-settings -n flux-system -o yaml

# 2. Check cluster-secrets Kustomization
kubectl describe kustomization cluster-secrets -n flux-system
kubectl get secret cluster-secrets -n flux-system -o yaml

# 3. Check cluster-apps Kustomization
kubectl describe kustomization cluster-apps -n flux-system
kubectl get kustomization -n flux-system  # List all child Kustomizations

# 4. Check GitRepository (source of truth)
kubectl describe gitrepository flux-system -n flux-system
kubectl get gitrepository flux-system -n flux-system -o yaml | grep -A 20 "status:"
```

## Common Flux Reconciliation Issues

### Issue: "No repository found"

**Symptom**: Kustomization shows `conditions: Ready=False`, error mentions repository

```bash
# Solution: Ensure GitRepository is ready
kubectl describe gitrepository flux-system -n flux-system

# Manually trigger git sync
flux reconcile source git flux-system -n flux-system
```

### Issue: "Kustomization patch target not found"

**Symptom**: Kustomize-controller logs show "failed to apply patch"

```bash
# Check what resources exist in the build output
flate -p ./kubernetes/clusters/korg/flux build cluster-apps | grep "^kind:"

# Verify patch target selector is correct in flux/ks.yaml
# Look for: annotationSelector, labelSelector
```

### Issue: "HelmRelease pending / not reconciling"

**Symptom**: HelmRelease stuck in Pending or shows helm errors

```bash
# Check helm state directly
helm list -n storage
helm history RELEASE_NAME -n storage
helm status RELEASE_NAME -n storage

# Check helm-controller logs
kubectl -n flux-system logs -f deployment/helm-controller --all-containers=true

# Force reconciliation
flux reconcile helmrelease RELEASE_NAME -n storage
```

### Issue: "CRD conflicts / already exists"

**Symptom**: Error about CRD already existing or conflicting field managers

```bash
# Check conflicting CRD
kubectl get crd NAME -o yaml | head -30

# Solution: Flux applies with --force-conflicts (should handle this)
# If persisting, try manual cleanup:
kubectl delete crd NAME --grace-period=0 --force
# Then retrigger reconciliation
```

### Issue: "Resources not being deleted"

**Symptom**: Resources linger after removing from git, Kustomization shows pruning issues

```bash
# Check Kustomization prune setting
kubectl get kustomization cluster-apps -n flux-system -o yaml | grep -A 5 "prune:"

# Check for blocking finalizers
kubectl get pods -A -o yaml | grep -A 2 "finalizers:" | head -20

# Force prune (dangerous - removes local changes):
flux reconcile kustomization cluster-apps -n flux-system --with-source

# Enable WaitForTermination in parent Kustomization if not present
# (ensures children finish deleting before parent reconciles)
```

## Rendering Specific Namespaces or Apps

```bash
# Render only storage namespace
flate -p ./kubernetes/clusters/korg/flux build all | sed -n '/^---$/,/^---$/p' | grep -A 1000 "namespace: storage" | head -100

# Extract all HelmReleases
flate -p ./kubernetes/clusters/korg/flux build all | grep -E "^(---$|apiVersion:|kind: HelmRelease|  name:)"

# Export specific resource
flate -p ./kubernetes/clusters/korg/flux build all | grep -A 100 "kind: HelmRelease" | grep -A 100 "name: rook-ceph-cluster" | head -50

# Count resources by type
flate -p ./kubernetes/clusters/korg/flux build all | grep "^kind:" | sort | uniq -c | sort -rn
```

## Cluster Comparison

When debugging differences between kdev and korg:

```bash
# Render both
flate -p ./kubernetes/clusters/kdev/flux build all > /tmp/kdev-render.yaml
flate -p ./kubernetes/clusters/korg/flux build all > /tmp/korg-render.yaml

# Extract resource counts
echo "=== kdev ===" && grep "^kind:" /tmp/kdev-render.yaml | sort | uniq -c
echo "=== korg ===" && grep "^kind:" /tmp/korg-render.yaml | sort | uniq -c

# Find differences (careful - will be large)
diff -u /tmp/kdev-render.yaml /tmp/korg-render.yaml | head -200

# Find resources in one cluster but not the other
comm -23 <(grep "^  name:" /tmp/kdev-render.yaml | sort -u) \
         <(grep "^  name:" /tmp/korg-render.yaml | sort -u)
```

## Performance & Large Manifests

For large clusters with many apps, the rendered manifest can be 10MB+:

```bash
# Check size of rendered output
flate -p ./kubernetes/clusters/korg/flux build all | wc -c

# Use paging for interactive review
flate -p ./kubernetes/clusters/korg/flux build all | less

# Extract summaries instead of full manifests
flate -p ./kubernetes/clusters/korg/flux build all | grep "^  name:" | sort -u | wc -l
flate -p ./kubernetes/clusters/korg/flux build all | grep "^kind:" | sort | uniq -c
```

## Validation Checklist for Changes

Before pushing changes to git:

- [ ] Render both clusters: `flate -p ./kubernetes/clusters/{kdev,korg}/flux build all > /tmp/cluster.yaml`
- [ ] Check for placeholders: `grep -i placeholder /tmp/cluster.yaml` (should be empty)
- [ ] Validate syntax: `kubectl apply -f /tmp/cluster.yaml --dry-run=client` (no errors)
- [ ] Compare to baseline if making large changes: `diff -u baseline.yaml /tmp/cluster.yaml | less`
- [ ] Verify HelmRelease counts match expectations
- [ ] Check that required Kustomizations are present in cluster-apps patches
