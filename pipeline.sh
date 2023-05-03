#!/usr/bin/env bash
#
# Installs or Uninstall Tekton Pipeline.
#

shopt -s inherit_errexit
set -eu -o pipefail

source "$(dirname ${BASH_SOURCE[0]})/common.sh"
source "$(dirname ${BASH_SOURCE[0]})/inputs.sh"

# argument to define what the script should do, "install" is the default
declare -r arg="${1:-install}"

[[ "${arg}" != "install" && "${arg}" != "uninstall" ]] &&
    fail "unknown argument '${arg}' informed, use either 'install' or 'uninstall'"

# full url to the tekton installation file, containing a number of kubernetes resources
readonly url=$(get_release_artifact_url "tektoncd/pipeline" ${INPUT_PIPELINE_VERSION})

#
# Uninstall
#

# short circuit to uninstall the release manifest, the exit-code of the "kubectl delete" command
# bellow will be returned directly as the end of the script
if [[ "${arg}" == "uninstall" ]]; then
    phase "Uninstalling Tekton Pipelines '${INPUT_PIPELINE_VERSION}'"
    set -x
    exec kubectl delete -f ${url}
fi

#
# Install
#

phase "Installing Tekton Pipeline '${INPUT_PIPELINE_VERSION}' on '${TEKTON_NAMESPACE}' namespace"
set -x
kubectl apply -f ${url}
set +x

phase "Waiting for Tekton Pipeline components"

rollout_status "${TEKTON_NAMESPACE}" "tekton-pipelines-controller"
rollout_status "${TEKTON_NAMESPACE}" "tekton-pipelines-webhook"

# graceful wait to give some more time for the tekton componets stabilize
sleep 30

if [[ -n "${INPUT_FEATURE_FLAGS}" && "${INPUT_FEATURE_FLAGS}" != "{}" ]]; then
    phase "Setting up the feature-flag(s): '${INPUT_FEATURE_FLAGS}'"

    set -x
    kubectl patch configmap/feature-flags \
        --namespace="${TEKTON_NAMESPACE}" \
        --type=merge \
        --patch="{ \"data\": ${INPUT_FEATURE_FLAGS} }"
    set +x

    # after patching the feature flags, making sure the rollout is not progressing again
    rollout_status "${TEKTON_NAMESPACE}" "tekton-pipelines-controller"
    rollout_status "${TEKTON_NAMESPACE}" "tekton-pipelines-webhook"
fi
