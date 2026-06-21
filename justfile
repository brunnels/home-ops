set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']

[group: 'bootstrap']
mod? bootstrap 'bootstrap'

[group: 'kubernetes']
mod? kube 'kubernetes'

[group: 'talos']
mod? talos 'talos'

[private]
default:
    just -l

[private]
log lvl msg *args:
    gum log -t rfc3339 -s -l "{{ lvl }}" "{{ msg }}" {{ args }}

[private]
[script]
set-cluster cluster:
    controller=$(yq .endpoint < {{ justfile_dir() }}/talos/{{ cluster }}/talconfig.yaml)
    kubectl config set-cluster {{ cluster }} --server ${controller}
