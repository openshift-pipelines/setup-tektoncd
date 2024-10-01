#
# Environment Variables with Default Values
#

# namespace name for the container registry
declare -rx REGISTRY_NAMESPACE="${REGISTRY_NAMESPACE:-registry}"
# the container registry uses the internal k8s service hosntame
declare -rx REGISTRY_HOSTNAME="${REGISTRY_HOSTNAME:-registry.registry.svc.cluster.local}"

# namespace name for Tekton Pipeline controller
declare -rx TEKTON_NAMESPACE="${TEKTON_NAMESPACE:-tekton-pipelines}"

# timeout employed during rollout status and deployments in general
declare -rx DEPLOYMENT_TIMEOUT="${DEPLOYMENT_TIMEOUT:-5m}"

#
# Helper Functions
#

# print error message and exit on error.
function fail() {
    echo "ERROR: ${*}" >&2
    exit 1
}

# print out a strutured message.
function phase() {
    echo "---> Phase: ${*}..."
}

# uses kubectl to check the deployment status on namespace and name informed.
function rollout_status() {
    local _namespace="${1}"
    local _deployment="${2}"

    if ! kubectl --namespace="${_namespace}" --timeout=${DEPLOYMENT_TIMEOUT} \
        rollout status deployment "${_deployment}"; then
        fail "'${_namespace}/${_deployment}' deployment failed after '${DEPLOYMENT_TIMEOUT}'!"
    fi
}

# inspect the path after the informed executable name.
function probe_bin_on_path() {
    if ! type -a ${1} >/dev/null 2>&1; then
        fail "Can't find '${1}' on 'PATH=${PATH}'"
    fi
}

# get the artifact url for the specific version (release) or latest.
function get_release_artifact_url() {
    local _org_repo="${1}"
    local _version="${2}"

    local _url="https://api.github.com/repos/${_org_repo}/releases"
    if [[ "${_version}" == "latest" ]]; then
        echo $(
            curl -s ${_url}/latest |
                jq -r '.assets[].browser_download_url' |
                egrep -i 'release.yaml' |
                head -n 1
        )
    else
        echo $(
            curl -s ${_url} |
                jq -r ".[] | select(.tag_name == \"${_version}\") | .assets[].browser_download_url" |
                egrep -i 'release.yaml' |
                head -n 1
        )
    fi
}
