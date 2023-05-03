#!/usr/bin/env bash
#
# Installs or uninstalls the Container Registry.
#

shopt -s inherit_errexit
set -eu -o pipefail

source "$(dirname ${BASH_SOURCE[0]})/common.sh"

# argument to define what the script should do, "install" is the default
declare -r arg="${1:-install}"

[[ "${arg}" != "install" && "${arg}" != "uninstall" ]] &&
    fail "unknown argument '${arg}' informed, use either 'install' or 'uninstall'"

# common name for the resources managed by this script
declare -r name="registry"
# label selector for the resources installed by this script
declare -r selector="action-setup-tektoncd-${name}"

#
# Uninstall
#

# short circuit to uninstall the resources based on the selector
if [[ "${arg}" == "uninstall" ]]; then
    phase "Uninstalling Registry using selector 'app=${selector}'"
    set -x
    exec kubectl --namespace="${REGISTRY_NAMESPACE}" \
        delete all --selector="app=${selector}"
fi

#
# Install
#

if ! kubectl get namespaces "${REGISTRY_NAMESPACE}" >/dev/null 2>&1; then
    phase "Creating Registry namespace '${REGISTRY_NAMESPACE}'"
    kubectl create namespace "${REGISTRY_NAMESPACE}"
fi

phase "Installing the Registry on '${REGISTRY_NAMESPACE}' namespace"
cat <<EOS |kubectl --namespace="${REGISTRY_NAMESPACE}" apply --output=yaml -f -
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: ${selector}
  name: ${name}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${selector}
  template:
    metadata:
      labels:
        app: ${selector}
    spec:
      containers:
        - name: ${name}
          image: registry:2
          imagePullPolicy: IfNotPresent
          env:
            - name: REGISTRY_STORAGE_DELETE_ENABLED
              value: "true"
          ports:
            - containerPort: 5000
          resources:
            requests:
              cpu: 100m
              memory: 128M
            limits:
              cpu: 100m
              memory: 128M
EOS

phase "Creating the Registry service on '${REGISTRY_NAMESPACE}' namespace"
cat <<EOS |kubectl --namespace="${REGISTRY_NAMESPACE}" apply --output=yaml -f -
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: ${selector}
  name: ${name}
spec:
  type: NodePort
  ports:
    - port: 32222
      nodePort: 32222
      protocol: TCP
      targetPort: 5000
  selector:
    app: ${selector}
EOS


phase "Waiting for Registry rollout (selector='${selector}')"
rollout_status "${REGISTRY_NAMESPACE}" "${name}"