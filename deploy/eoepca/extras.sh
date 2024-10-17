#!/usr/bin/env bash

ORIG_DIR="$(pwd)"
cd "$(dirname "$0")"
BIN_DIR="$(pwd)"

onExit() {
  cd "${ORIG_DIR}"
}

trap onExit EXIT

source ../cluster/functions
configureAction "$1"
initIpDefaults

NAMESPACE="extras"

main() {
    if [ "${ACTION_HELM}" = "uninstall" ]; then
        helm --namespace "${NAMESPACE}" uninstall prometheus
    else
        helm ${ACTION_HELM} prometheus prometheus \
        --repo https://prometheus-community.github.io/helm-charts \
        --create-namespace \
        --namespace "${NAMESPACE}"
        echo "[INFO]  Wait for prometheus ready..."
        checkIfPrometheusIsRunning
        echo "[INFO]  ...prometheus READY."
        export POD_NAME=$(kubectl get pods --namespace extras -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -o jsonpath="{.items[0].metadata.name}")
        kubectl --namespace extras port-forward $POD_NAME 9090
    fi


}

checkIfPrometheusIsRunning() {
    interval=$(( 1 ))
    msgInterval=$(( 5 ))
    step=$(( msgInterval / interval ))
    count=$(( 0 ))
    status=$(( 1 ))
    while [ "${status}" != "Running" ]
    do
        status=$(kubectl get pods --namespace extras -l "app.kubernetes.io/name=prometheus,app.kubernetes.io/instance=prometheus" -ojson | jq '.items[].status.phase' | xargs)
        echo "Status is: '$status'"
        if [ "${status}" = "Running" ]; then break; fi
        test $(( count % step )) -eq 0 && echo "[INFO]  Waiting for service/prometheus"
        sleep $interval
        count=$(( count + interval ))
    done
}

main "$@"
