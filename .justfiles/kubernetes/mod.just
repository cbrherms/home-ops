set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just -l kube

[doc('Apply local Flux Kustomization')]
apply-ks ns ks:
    flux build --namespace {{ ns }} ks {{ ks }} \
        --kustomization-file kubernetes/main/apps/{{ ns }}/{{ ks }}/ks.yaml \
        --path kubernetes/main/apps/{{ ns }}/{{ ks }} \
        | yq 'with(select(.apiVersion == "kustomize.toolkit.fluxcd.io/v1" and .kind == "Kustomization"); .metadata.namespace = "{{ ns }}")' - \
        | kubectl apply --server-side --field-manager=kustomize-controller --filename -

[doc('Browse a PVC')]
browse-pvc ns claim:
    kubectl run -n {{ ns }} browse-pvc-{{ claim }} -it --rm --restart=Never \
        --image=mirror.gcr.io/alpine:latest \
        --overrides='{"spec":{"containers":[{"name":"browse-pvc-{{ claim }}","image":"mirror.gcr.io/alpine:latest","stdin":true,"tty":true,"command":["/bin/sh"],"workingDir":"/mnt","volumeMounts":[{"mountPath":"/mnt","name":"data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"{{ claim }}"}}]}}'

[doc('Debug a node')]
[script]
debug-node node:
    trap 'kubectl delete pod -n default -l app.kubernetes.io/managed-by=kubectl-debug --field-selector spec.nodeName={{ node }} --ignore-not-found --wait=false' EXIT
    kubectl debug node/{{ node }} -n default -it --image=mirror.gcr.io/alpine:latest --profile=sysadmin

[doc('Prune pods in Failed, Pending, or Succeeded state')]
[script]
prune-pods:
    for phase in Failed Pending Succeeded; do
        kubectl delete pods -A --field-selector status.phase="$phase" --ignore-not-found=true
    done

[doc('Force sync all ExternalSecrets')]
[script]
sync-es:
    kubectl get externalsecret --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" annotate externalsecret "$name" \
            --field-manager=flux-client-side-apply \
            --overwrite force-sync="$(date +%s)"
    done

[arg('resource', pattern='hr|ks|gitrepo|ocirepo')]
[doc('Sync a Flux resource across all namespaces')]
[script]
sync resource:
    kubectl get {{ resource }} --no-headers -A | while read -r ns name _; do
        kubectl -n "$ns" annotate --field-manager flux-client-side-apply --overwrite {{ resource }} "$name" \
            "force-sync=$(date +%s)" \
            "reconcile.fluxcd.io/requestedAt=$(date +%s)" \
            "reconcile.fluxcd.io/forceAt=$(date +%s)"
    done

[doc('Validate Kubernetes manifests with kubeconform')]
kubeconform:
    bash scripts/kubeconform.sh kubernetes/main

[doc('Gather common cluster resources')]
[script]
resources:
    for r in nodes gitrepositories kustomizations helmrepositories helmreleases certificates certificaterequests ingresses pods; do
        kubectl get "$r" -A
    done

[doc('Upgrade ARC runner scale sets')]
upgrade-arc:
    helm -n actions-runner-system uninstall gha-runner-scale-set
    helm -n actions-runner-system uninstall gha-runner-scale-set-controller
    sleep 5
    flux -n actions-runner-system reconcile hr gha-runner-scale-set-controller
    flux -n actions-runner-system reconcile hr gha-runner-scale-set


