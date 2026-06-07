set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just -l op

# Test 1Password connection
[doc('Test 1Password connection')]
test:
    op whoami

# Compare 1Password kubeconfig with local kubeconfig
[doc('Compare 1Password and local kubeconfig')]
[script]
compare:
    op_config=$(op item get kubernetes --fields label=KUBECONFIG_MAIN | tr -d '"')
    local_config=$(kubectl config view --flatten)
    if diff <(echo "$op_config") <(echo "$local_config") > /dev/null 2>&1; then
        echo "OK: 1Password and local kubeconfig match"
    else
        echo "MISMATCH: 1Password and local kubeconfig differ"
        diff <(echo "$op_config") <(echo "$local_config")
        exit 1
    fi

# Push all kubeconfigs/talosconfigs to 1Password
[doc('Push all kubeconfigs to 1Password')]
push: push-main
    op item edit kubernetes KUBECONFIG[text]="$(kubectl config view --flatten)" &>/dev/null
    op item edit kubernetes KUBECONFIG_BASE64[text]="$(kubectl config view --flatten | base64 -w 0)" &>/dev/null

# Push main cluster kubeconfig and talosconfig to 1Password
[doc('Push main kubeconfig and talosconfig to 1Password')]
push-main:
    op item edit kubernetes KUBECONFIG_MAIN[text]="$(cat {{ justfile_directory() }}/kubernetes/main/kubeconfig)" &>/dev/null
    op item edit kubernetes TALOSCONFIG_MAIN[text]="$(cat {{ justfile_directory() }}/kubernetes/main/bootstrap/talos/clusterconfig/talosconfig)" &>/dev/null
    op item edit kubernetes TALOSCONFIG_MAIN_BASE64[text]="$(cat {{ justfile_directory() }}/kubernetes/main/bootstrap/talos/clusterconfig/talosconfig | base64 -w 0)" &>/dev/null

# Pull main cluster kubeconfig and talosconfig from 1Password
[doc('Pull kubeconfigs from 1Password')]
pull:
    mkdir -p ~/.kube ~/.talos
    op item get kubernetes --fields label=KUBECONFIG_MAIN | tr -d '"' > {{ justfile_directory() }}/kubernetes/main/kubeconfig
    op item get kubernetes --fields label=TALOSCONFIG_MAIN | tr -d '"' > {{ justfile_directory() }}/kubernetes/main/bootstrap/talos/clusterconfig/talosconfig
    op item get kubernetes --fields label=KUBECONFIG | tr -d '"' > ~/.kube/config
    op item get kubernetes --fields label=TALOSCONFIG_MAIN | tr -d '"' > ~/.talos/config
    talosctl config merge {{ justfile_directory() }}/kubernetes/main/bootstrap/talos/clusterconfig/talosconfig --talosconfig ~/.talos/config
