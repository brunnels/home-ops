set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']
set working-directory := "../talos"

[private]
default:
    just -l talos

[doc('Apply Talos config to all nodes (shows a diff and asks first)')]
[group('talos')]
[script]
apply cluster:
    cd "{{ cluster }}"
    topf apply

[arg('mode', pattern='auto|reboot|no-reboot|staged|try')]
[doc('Apply Talos config to a node (shows a diff and asks first)')]
[group('talos')]
[script]
apply-node node cluster mode='auto':
    cd "{{ cluster }}"
    topf apply --nodes-filter "^{{ node }}$" --mode "{{ mode }}"

[doc('Show pending config changes without applying them')]
[group('talos')]
[script]
diff cluster:
    cd "{{ cluster }}"
    topf apply --dry-run

[doc('List all nodes and their current state')]
[group('talos')]
[script]
nodes cluster:
    cd "{{ cluster }}"
    topf nodes

[doc('Render Talos machine configs to ./rendered (2-space indented)')]
[group('talos')]
[script]
render cluster:
    cd "{{ cluster }}"
    topf render --output ./rendered
    yamlfmt -formatter indent=2,retain_line_breaks=true ./rendered/*.yaml

[confirm("This will destroy your cluster and reset all nodes to maintenance mode — continue? [y/N]")]
[doc('Reset all nodes back to maintenance mode (DESTRUCTIVE)')]
[group('talos')]
[script]
reset cluster:
    cd "{{ cluster }}"
    topf reset --confirm=false

[confirm("This will reset the specified node to maintenance mode — continue? [y/N]")]
[doc('Reset a single node back to maintenance mode (DESTRUCTIVE)')]
[group('talos')]
[script]
reset-node node cluster:
    cd "{{ cluster }}"
    topf reset --nodes-filter "^{{ node }}$" --confirm=false

# topf intentionally does not manage Kubernetes upgrades
[doc('Upgrade Kubernetes')]
[group('talos')]
[script]
upgrade-k8s cluster:
    cd "{{ cluster }}"
    talosctl --nodes "$(yq '[.nodes[] | select(.role == "control-plane")][0].ip' topf.yaml)" \\
        upgrade-k8s --to "$(yq '.kubernetesVersion' topf.yaml)"

[doc('Upgrade Talos on all nodes, one at a time (asks first)')]
[group('talos')]
[script]
upgrade cluster:
    cd "{{ cluster }}"
    topf upgrade

[doc('Upgrade Talos on a single node (asks first)')]
[group('talos')]
[script]
upgrade-node node cluster:
    cd "{{ cluster }}"
    topf upgrade --nodes-filter "^{{ node }}$"
