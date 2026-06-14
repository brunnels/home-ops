set no-exit-message
set quiet
set shell := ['bash', '-euo', 'pipefail', '-c']
set script-interpreter := ['bash', '-euo', 'pipefail']

kubernetes_dir := justfile_dir() + '/kubernetes'
scripts_dir := justfile_dir() + "/scripts"
cluster_dir := justfile_dir() + '/kubernete/clusters'

[private]
default:
    just -l bootstrap

[doc('Bootstrap the Talos cluster')]
[group('bootstrap')]
talos cluster='':
    just bootstrap talos-secret "{{ cluster }}"
    just talos generate-config "{{ cluster }}"
    just bootstrap talos-apply "{{ cluster }}"
    just bootstrap talos-bootstrap "{{ cluster }}"
    just bootstrap talos-kubeconfig "{{ cluster }}"

[doc('Bootstrap apps into the Talos cluster')]
[group('bootstrap')]
[script]
apps cluster='':
    just log info "$(just set-cluster "{{ cluster }}")"
    just bootstrap apps-ready "{{ cluster }}"
    just bootstrap apps-crds
    just bootstrap apps-resources "{{ cluster }}"
    just log info "Cluster is bootstrapped — Flux will start syncing the Git repository" cluster "{{ cluster }}"

[private]
[script]
[working-directory('../talos')]
talos-secret cluster='':
    just log info "Generating talsecret" cluster "{{ cluster }}"
    cd "{{ cluster }}"
    if [ ! -f talsecret.sops.yaml ]; then
        talhelper gensecret | sops --filename-override talsecret.sops.yaml --encrypt /dev/stdin > talsecret.sops.yaml
    fi

[private]
[script]
[working-directory('../talos')]
talos-apply cluster='':
    just log info "Applying talos config" cluster "{{ cluster }}"
    cd "{{ cluster }}"
    talhelper gencommand apply --extra-flags="--insecure" | bash

[private]
[script]
[working-directory('../talos')]
talos-bootstrap cluster='':
    just log info "Bootstrapping talos" cluster "{{ cluster }}"
    cd "{{ cluster }}"
    until talhelper gencommand bootstrap | bash; do sleep 10; done

#[private]
[script]
[working-directory('../talos')]
talos-kubeconfig cluster='':
    just log info "Fetching kubeconfig" cluster "{{ cluster }}"
    cd "{{ cluster }}"
    until talhelper gencommand kubeconfig --extra-flags="{{ justfile_dir() }} --force --force-context-name {{ cluster }}" | bash; do sleep 10; done

[private]
[script]
apps-crds:
    just log info "Applying CRDs"
    if ! helmfile --file "{{ source_directory() }}/helmfile/crds.yaml" template --quiet | yq eval-all --exit-status 'select(.kind == "CustomResourceDefinition")' | kubectl apply --server-side --force-conflicts --filename -; then
        just log fatal "Failed to apply crds"
    fi

[private]
[script]
apps-helm:
    just log info "Syncing helmfile"
    if ! helmfile --file "{{ source_directory() }}/helmfile/apps.yaml" sync --hide-notes; then
        just log fatal "Failed to sync helmfile"
    fi

[private]
[script]
create-namespace ns:
    just log info "Creating namespace {{ ns }}"
    if kubectl get namespace {{ ns }} &>/dev/null; then
        just log info "Namespace already exists" namespace "{{ ns }}"
    elif kubectl create namespace "{{ ns }}" --dry-run=client -o yaml \
            | kubectl apply --server-side --filename - &>/dev/null; then
        just log info "Namespace created" namespace "{{ ns }}"
    else
        just log fatal "Failed to create namespace" namespace "{{ ns }}"
    fi

[private]
[script]
create-resource type name ns:
    just log info "Creating {{ type }} {{ name }}" namespace "{{ ns }}"
    if kubectl -n {{ ns }} get {{ type }} {{ name }} &>/dev/null; then
        just log info "{{ type }} {{ name }} already exists" namespace "{{ ns }}"
        exit 0
    fi
    export NAMESPACE="{{ ns }}"
    bootstrap_file="{{ source_directory() }}/{{ name }}.yaml"

    if ! output=$(envsubst < "${bootstrap_file}" | "{{ scripts_dir }}/akeyless.sh" 2>/dev/null) || [[ -z "${output}" ]]; then
        just log fatal "Failed to render bootstrap_file" "bootstrap_file=${bootstrap_file}"
    fi

    #echo "${output}" > "{{ justfile_dir() }}/{{ name }}.yaml"

    # Apply resources
    if echo "${output}" | kubectl apply --server-side --filename -; then
        just log info "{{ type }} {{ name }} created" namespace "{{ ns }}"
    else
        just log fatal "Failed to create {{ type }} {{ name }}" namespace "{{ ns }}"
    fi

[private]
[script]
apps-resources cluster='':
    just log info "Applying resources" cluster "{{ cluster }}"

    # load cluster settings into environment variables
    settings_file="{{ kubernetes_dir }}/clusters/{{ cluster }}/cluster-settings/cluster-settings.yaml"

    if [[ ! -f "${settings_file}" ]]; then
        just log fatal "cluster-settings.yaml file does not exist" "settings_file=${settings_file}"
    fi

    data_keys=$(yq e '.data | keys | .[]' "${settings_file}")

    for key in ${data_keys}; do
        value=$(yq e ".data.\"${key}\"" "${settings_file}")
        export "${key}"="${value}"
    done

    export VAULT_PREFIX="{{ cluster }}"
    export SECRET_DOMAIN="$(echo "ak://${VAULT_PREFIX}-cluster/SECRET_DOMAIN" | "{{ scripts_dir }}/akeyless.sh")"
    export CERT_NAME="${SECRET_DOMAIN/\./-}"
    export CLUSTER="{{ cluster }}"

    apps_dir="{{ kubernetes_dir }}/{{ cluster}}"
    for app in "${apps_dir}"/*/; do
        ns=$(basename "${app}")
        just bootstrap create-namespace "${ns}"
        just log info "$(kubectl -n "${ns}" apply --server-side --force-conflicts --filename="${settings_file}")" namespace "${ns}"
        just bootstrap create-resource "secret" "cluster-secrets" "${ns}"
    done
    just bootstrap create-resource "secret" "akeyless" "external-secrets"
    just bootstrap apps-helm
    just log info "Resources applied"

# Wait until nodes register as Ready=False. They only become Ready=True once the CNI is healthy.
[private]
[script]
apps-ready cluster='':
    just log info "Waiting for nodes to register as Ready=False" cluster "{{ cluster }}"
    if ! kubectl wait nodes --for=condition=Ready=True --all --timeout=10s &>/dev/null; then
        until kubectl wait nodes --for=condition=Ready=False --all --timeout=10s &>/dev/null; do
            just log info "Nodes not available, waiting for nodes to be available. Retrying in 5 seconds..."
            sleep 5
        done
    fi
