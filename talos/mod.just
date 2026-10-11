set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']
set working-directory := "../talos"

[private]
default:
    just -l talos

[private]
[script]
nodeip cluster node:
    cd "{{ cluster }}"
    topf nodes --nodes-filter "^{{ node }}$" -o yaml | yq .[].node.ip

[private]
[script]
talosctl cluster node command:
    cd "{{ cluster }}"
    talosctl --talosconfig=talosconfig --nodes "$(just talos nodeip {{ cluster }} {{ node }})" {{ command }}

[private]
[script]
schematic-id cluster:
    cd "{{ cluster }}"

    # Retry logic for curl request
    MAX_RETRIES=10
    RETRY_COUNT=0
    PAYLOAD="$(yq schematic.yaml)"
    RESPONSE=""
    while [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; do
        if RESPONSE=$(curl -sX POST -f --connect-timeout 3 --max-time 5 \
          -d "$PAYLOAD" \
          https://factory.talos.dev/schematics); then
            break
        fi

        RETRY_COUNT=$((RETRY_COUNT + 1))
        if [[ $RETRY_COUNT -lt $MAX_RETRIES ]]; then
            just log info "  Request failed, retrying... (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)" >&2
            sleep 2
        fi
    done

    if [[ -z "$RESPONSE" ]]; then
        just log error "Failed to get response from factory.talos.dev after $MAX_RETRIES attempts" >&2
        exit 1
    fi
    SCHEMATIC_ID=$(echo "$RESPONSE" | jq -r '.id')
    echo "$SCHEMATIC_ID"

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

[doc('Render Talos machine configs to ./rendered')]
[group('talos')]
[script]
render cluster:
    cd "{{ cluster }}"
    mkdir -p ./rendered
    topf render --output ./rendered
    topf talosconfig > ./talosconfig
    yamlfmt -formatter indent=2,retain_line_breaks=true ./rendered/*.yaml

[confirm("This will destroy your cluster and reset all nodes to maintenance mode — continue? [y/N]")]
[doc('Reset all nodes back to maintenance mode (DESTRUCTIVE)')]
[group('talos')]
[script]
reset cluster full='false':
    cd "{{ cluster }}"
    topf reset --confirm=false --full={{ full }} --graceful=false --wait-for-maintenance=true

[confirm("This will reset the specified node to maintenance mode — continue? [y/N]")]
[doc('Reset a single node back to maintenance mode (DESTRUCTIVE)')]
[group('talos')]
[script]
reset-node cluster node full='false':
    cd "{{ cluster }}"
    topf reset --nodes-filter "^{{ node }}$" --confirm=false --full={{ full }} --graceful=false --wait-for-maintenance=true

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
upgrade-node cluster node:
    cd "{{ cluster }}"
    topf upgrade --submit-to-factory --nodes-filter "^{{ node }}$"

[doc('Shutdown a single Talos node using talosctl')]
[group('talos')]
[script]
shutdown-node cluster node:
    just talos talosctl {{ cluster }} {{ node }} shutdown

[doc('Reboot a single Talos node using talosctl')]
[group('talos')]
[script]
reboot-node cluster node:
    just talos talosctl {{ cluster }} {{ node }} reboot
