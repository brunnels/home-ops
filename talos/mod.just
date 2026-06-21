set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']
set working-directory := "../talos"

[private]
default:
    just -l talos

[doc('Apply Talos config to a node')]
[group('talos')]
[script]
apply-node ip cluster mode='auto':
    cd "{{ cluster }}"
    talhelper gencommand apply --node "{{ ip }}" --extra-flags "--mode={{ mode }}" | bash

[doc('Generate Talos configuration')]
[group('talos')]
[script]
generate-config cluster:
    cd "{{ cluster }}"
    talhelper genconfig

[confirm("This will destroy your cluster and reset all nodes to maintenance mode — continue? [y/N]")]
[doc('Reset all nodes back to maintenance mode (DESTRUCTIVE)')]
[group('talos')]
[script]
reset cluster:
    cd "{{ cluster }}"
    talhelper gencommand reset --extra-flags="--reboot --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL \
    --graceful=false --wait=false" | bash

[confirm("This will reset the specified node to maintenance mode — continue? [y/N]")]
[doc('Reset a single node back to maintenance mode (DESTRUCTIVE)')]
[group('talos')]
[script]
reset-node ip cluster:
    cd "{{ cluster }}"
    talhelper gencommand reset --extra-flags="--reboot --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL \
    --graceful=false --wait=false" --node "{{ ip }}" | bash

[doc('Upgrade Kubernetes')]
[group('talos')]
[script]
upgrade-k8s cluster:
    cd "{{ cluster }}"
    talhelper gencommand upgrade-k8s --extra-flags "--to '$(yq '.kubernetesVersion' talenv.yaml)'" | bash

[doc('Upgrade Talos on a single node')]
[group('talos')]
[script]
upgrade-node ip cluster:
    cd "{{ cluster }}"
    talhelper gencommand upgrade --node "{{ ip }}" --extra-flags "--timeout=10m" | bash
