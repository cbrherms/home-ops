set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

_cluster_dir := justfile_directory() + "/kubernetes/main"
_talos_dir := justfile_directory() + "/kubernetes/main/bootstrap/talos"
_sops_age_key := justfile_directory() + "/age.key"

[private]
default:
    just -l bootstrap

[doc('Generate a Sops Age key (skips if already exists)')]
age-keygen:
    test -f {{ _sops_age_key }} || age-keygen --output {{ _sops_age_key }}

[doc('Bootstrap the Talos cluster')]
[script]
talos:
    # Generate talsecret if it doesn't exist yet, then encrypt it
    if [ ! -f {{ _talos_dir }}/talsecret.sops.yaml ]; then
        talhelper gensecret > {{ _talos_dir }}/talsecret.sops.yaml
        sops --encrypt --in-place {{ _talos_dir }}/talsecret.sops.yaml
    fi
    # Generate machine configs
    talhelper genconfig \
        --config-file {{ _talos_dir }}/talconfig.yaml \
        --secret-file {{ _talos_dir }}/talsecret.sops.yaml \
        --out-dir {{ _talos_dir }}/clusterconfig
    # Apply configs to nodes (insecure - nodes are in maintenance mode)
    talhelper gencommand apply \
        --config-file {{ _talos_dir }}/talconfig.yaml \
        --out-dir {{ _talos_dir }}/clusterconfig \
        --extra-flags="--insecure" | bash
    # Bootstrap etcd (retry until the first control plane node is ready)
    until talhelper gencommand bootstrap \
        --config-file {{ _talos_dir }}/talconfig.yaml \
        --out-dir {{ _talos_dir }}/clusterconfig | bash; do sleep 10; done
    # Generate kubeconfig (retry until apiserver is available)
    until talhelper gencommand kubeconfig \
        --config-file {{ _talos_dir }}/talconfig.yaml \
        --out-dir {{ _talos_dir }}/clusterconfig \
        --extra-flags="{{ _cluster_dir }} --force" | bash; do sleep 10; done
    # Install core apps via helmfile (cilium, coredns, etc.)
    just bootstrap _apps
    # Final health check
    talosctl health --server=false

# Install core cluster apps via helmfile (called by talos bootstrap)
[private]
[script]
_apps:
    until kubectl wait --for=condition=Ready=False nodes --all --timeout=600s; do sleep 10; done
    helmfile --file {{ _cluster_dir }}/bootstrap/helmfile.yaml apply --skip-diff-on-install --suppress-diff
    until kubectl wait --for=condition=Ready nodes --all --timeout=600s; do sleep 10; done

[doc('Bootstrap Flux into the cluster')]
[script]
flux:
    # Apply GitHub deploy key if present
    if [ -f {{ _cluster_dir }}/bootstrap/flux/github-deploy-key.sops.yaml ]; then
        kubectl create namespace flux-system --dry-run=client -o yaml | kubectl apply --filename -
        sops exec-file {{ _cluster_dir }}/bootstrap/flux/github-deploy-key.sops.yaml \
            "kubectl apply --server-side --filename {}"
    fi
    # Apply Flux bootstrap kustomization
    kubectl apply --server-side --kustomize {{ _cluster_dir }}/bootstrap/flux
    # Create sops-age secret if it doesn't exist yet
    if ! kubectl --namespace flux-system get secret sops-age &>/dev/null; then
        kubectl --namespace flux-system create secret generic sops-age \
            --from-file=age.agekey={{ _sops_age_key }}
    fi
    # Apply cluster secrets, settings, and Flux config
    sops exec-file {{ _cluster_dir }}/flux/settings/cluster-secrets.sops.yaml \
        "kubectl apply --server-side --filename {}"
    kubectl apply --server-side --filename {{ _cluster_dir }}/flux/settings/cluster-settings.yaml
    kubectl apply --server-side --kustomize {{ _cluster_dir }}/flux/config

[doc('Encrypt any unencrypted sops secret files')]
[script]
secrets:
    find "{{ justfile_directory() }}/kubernetes" -type f -name "*.sops.*" | while read -r file; do
        if sops filestatus "$file" | jq --exit-status '.encrypted == false' &>/dev/null; then
            sops --encrypt --in-place "$file"
        fi
    done

[doc('Post-bootstrap cleanup - removes template scaffolding (one-time operation)')]
[confirm('This will delete CI test files and move bootstrap/makejinja artifacts to .private/. Continue?')]
[script]
clean:
    ts=$(date +%s)
    mkdir -p {{ justfile_directory() }}/.private
    # Remove CI and devcontainer scaffolding
    rm -rf {{ justfile_directory() }}/.github/tests
    rm -rf {{ justfile_directory() }}/.github/workflows/e2e.yaml
    rm -rf {{ justfile_directory() }}/.devcontainer/ci
    rm -rf {{ justfile_directory() }}/.github/workflows/devcontainer.yaml
    # Archive bootstrap dir and makejinja config
    [ -d {{ justfile_directory() }}/bootstrap ] && \
        mv {{ justfile_directory() }}/bootstrap {{ justfile_directory() }}/.private/bootstrap-${ts}
    [ -f {{ justfile_directory() }}/makejinja.toml ] && \
        mv {{ justfile_directory() }}/makejinja.toml {{ justfile_directory() }}/.private/makejinja-${ts}.toml
    # Remove .j2 extension hints from renovate config
    sed -i 's/(..\.j2)\?//g' {{ justfile_directory() }}/.github/renovate.json5
