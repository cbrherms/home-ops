set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just -l volsync

[doc('List VolSync snapshots for an app')]
[script]
list ns app:
    export NS="{{ ns }}"
    export APP="{{ app }}"
    minijinja-cli --env {{ justfile_directory() }}/.justfiles/volsync/resources/list.yaml.j2 | kubectl apply -f -
    kubectl -n {{ ns }} wait job/list-{{ app }} --for=condition=complete --timeout=1m
    kubectl -n {{ ns }} logs job/list-{{ app }} --container list
    kubectl -n {{ ns }} delete job list-{{ app }}

[doc('Snapshot all VolSync PVCs')]
[script]
snapshot:
    kubectl get replicationsources --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" patch replicationsources "$name" --type merge -p '{"spec":{"trigger":{"manual":"$(date +%s)"}}}'
    done

[doc('Snapshot a specific app PVC')]
snapshot-app ns app:
    kubectl -n {{ ns }} patch replicationsources {{ app }} --type merge -p '{"spec":{"trigger":{"manual":"$(date +%s)"}}}'
    @until kubectl -n {{ ns }} get job/volsync-src-{{ app }} &>/dev/null; do sleep 5; done
    kubectl -n {{ ns }} wait job/volsync-src-{{ app }} --for=condition=complete --timeout=120m

[arg('state', pattern='suspend|resume')]
[doc('Suspend or resume VolSync')]
volsync state:
    flux --namespace flux-system {{ state }} kustomization volsync
    flux --namespace storage {{ state }} helmrelease volsync
    kubectl --namespace storage scale deployment volsync --replicas {{ if state != "suspend" { "1" } else { "0" } }}

[doc('Unlock all Restic repos')]
[script]
unlock:
    kubectl get replicationsources --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" patch --field-manager=flux-client-side-apply replicationsources "$name" \
            --type merge --patch "{\"spec\":{\"restic\":{\"unlock\":\"$(date +%s)\"}}}"
    done

[doc('Restore an app from VolSync (Restic)')]
[script]
restore ns app previous='0':
    export NS="{{ ns }}"
    export APP="{{ app }}"
    export PREVIOUS="{{ previous }}"
    export CLAIM=$(kubectl -n {{ ns }} get replicationsources/{{ app }} -o jsonpath="{.spec.sourcePVC}")
    export ACCESS_MODES=$(kubectl -n {{ ns }} get replicationsources/{{ app }} -o jsonpath="{.spec.restic.accessModes}")
    export STORAGE_CLASS_NAME=$(kubectl -n {{ ns }} get replicationsources/{{ app }} -o jsonpath="{.spec.restic.storageClassName}")
    export PUID=$(kubectl -n {{ ns }} get replicationsources/{{ app }} -o jsonpath="{.spec.restic.moverSecurityContext.runAsUser}")
    export PGID=$(kubectl -n {{ ns }} get replicationsources/{{ app }} -o jsonpath="{.spec.restic.moverSecurityContext.runAsGroup}")
    controller=$(kubectl -n {{ ns }} get deployment {{ app }} &>/dev/null && echo deployment || echo statefulset)
    flux --namespace flux-system suspend kustomization {{ app }}
    flux --namespace {{ ns }} suspend helmrelease {{ app }}
    kubectl --namespace {{ ns }} scale "$controller/{{ app }}" --replicas 0
    kubectl --namespace {{ ns }} wait pod --for=delete --selector="app.kubernetes.io/name={{ app }}" --timeout=5m
    minijinja-cli {{ justfile_directory() }}/.justfiles/volsync/resources/replicationdestination.yaml.j2 \
        | kubectl apply --server-side --filename -
    until kubectl -n {{ ns }} get job/volsync-dst-{{ app }}-manual &>/dev/null; do sleep 5; done
    kubectl -n {{ ns }} wait job/volsync-dst-{{ app }}-manual --for=condition=complete --timeout=120m
    kubectl -n {{ ns }} delete replicationdestination {{ app }}-manual
    flux --namespace flux-system resume kustomization {{ app }}
    flux --namespace {{ ns }} resume helmrelease {{ app }}
    flux --namespace {{ ns }} reconcile helmrelease {{ app }} --force
    kubectl --namespace {{ ns }} wait pod --for=condition=ready --selector="app.kubernetes.io/name={{ app }}" --timeout=5m
