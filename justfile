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

[doc('Yoinks a file or folder from GitHub. Usage: just fetch URL [DESTINATION]')]
[group('utilities')]
[script]
yoink url dest='.':
    set -euo pipefail

    # Validate destination exists
    if ! test -d "{{ dest }}"; then
        echo "Error: Invalid destination directory '{{ dest }}'" >&2
        exit 1
    fi

    # Validate source URL is reachable (HTTP 200)
    http_code=$(curl -s -o /dev/null -I -w "%{http_code}" "{{ url }}" || echo "000")
    if [[ "$http_code" != "200" ]]; then
        echo "Error: Invalid source URL or URL is not accessible: {{ url }} (HTTP $http_code)" >&2
        exit 1
    fi

    # Run the Python fetcher script
    python3 "{{ justfile_dir() }}/scripts/fetcher.py" "{{ url }}" --output_dir "{{ dest }}"

[doc('Switches the context to the desired cluster. Usage: just set-cluster CLUSTER')]
[group('utilities')]
[script]
set-cluster cluster:
    kubectl config use-context {{ cluster }}
