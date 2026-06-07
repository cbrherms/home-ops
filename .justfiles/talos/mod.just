set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

_cluster_dir := justfile_directory() + "/kubernetes/main"
_talos_dir := justfile_directory() + "/kubernetes/main/bootstrap/talos"

[private]
default:
    just -l talos

# Wait for all cluster jobs to complete before a disruptive operation
# TODO: add 'just volsync volsync suspend' here once volsync module is verified
[private]
_down:
    until kubectl wait jobs --all --all-namespaces --for=condition=complete --timeout=5m &>/dev/null; do sleep 5; done

# Wait for all cluster jobs to settle after a disruptive operation
# TODO: add 'just volsync volsync resume' here once volsync module is verified
[private]
_up:
    until kubectl wait jobs --all --all-namespaces --for=condition=complete --timeout=5m &>/dev/null; do sleep 5; done

[doc('Show current TALOSCONFIG path')]
test:
    echo $TALOSCONFIG

[doc('Generate Talos machine configs via talhelper')]
genconfig:
    talhelper -c {{ _talos_dir }}/talconfig.yaml genconfig \
        -s {{ _talos_dir }}/talsecret.sops.yaml \
        -o {{ _talos_dir }}/clusterconfig

[doc('Apply Talos config to a node')]
apply-node hostname mode='auto': _down
    talosctl apply-config \
        --nodes {{ hostname }} \
        --mode={{ mode }} \
        --file {{ _talos_dir }}/clusterconfig/main-{{ hostname }}.yaml
    talosctl --nodes {{ hostname }} health --wait-timeout=10m --server=false
    just talos _up

[doc('Upgrade Talos on a single node')]
[script]
upgrade-node hostname: _down
    schematic_id=$(yq '.nodes[] | select(.hostname == "{{ hostname }}") | .talosImageURL' {{ _talos_dir }}/talconfig.yaml | awk -F/ '{print $NF}')
    secureboot=$(yq '.nodes[] | select(.hostname == "{{ hostname }}") | .machineSpec.secureboot' {{ _talos_dir }}/talconfig.yaml)
    talos_version=$(yq '.talosVersion' {{ _talos_dir }}/talconfig.yaml)
    if [ "$secureboot" = "false" ]; then
        image="factory.talos.dev/installer-secureboot/${schematic_id}:${talos_version}"
    else
        image="factory.talos.dev/installer/${schematic_id}:${talos_version}"
    fi
    talosctl --nodes {{ hostname }} upgrade --image="$image" --timeout=10m
    talosctl --nodes {{ hostname }} health --wait-timeout=10m --server=false
    just talos _up

[doc('Upgrade Kubernetes across the cluster')]
[script]
upgrade-k8s:
    controller=$(talosctl config info --output json | jq --raw-output '.endpoints[]' | shuf -n 1)
    k8s_version=$(yq '.kubernetesVersion' {{ _talos_dir }}/talconfig.yaml)
    talosctl --nodes "$controller" upgrade-k8s --to "$k8s_version"

[doc('Reset nodes back to maintenance mode (destructive)')]
[confirm('This will destroy your cluster and reset nodes to maintenance mode. Continue?')]
reset:
    talhelper gencommand reset \
        --config-file {{ _talos_dir }}/talconfig.yaml \
        --out-dir {{ _talos_dir }}/clusterconfig \
        --extra-flags="--reboot --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --graceful=false --wait=false" \
        | bash

[doc('Generate kubeconfig for the cluster')]
[script]
kubeconfig:
    controller=$(talosctl config info --output json | jq --raw-output '.endpoints[]' | shuf -n 1)
    talosctl kubeconfig --nodes "$controller" --force --force-context-name main {{ _cluster_dir }}
