#!/bin/bash

set -o errexit # Bail out on any error

########################################################################################################################
# Define constants here
fluxCDChartUrl="https://charts.fluxcd.io"
fluxNamespace="flux"
fluxDirectory="flux"

helmOperatorCrdUrl="https://raw.githubusercontent.com/fluxcd/helm-operator/master/deploy/crds.yaml"
helmVersion="v3"
########################################################################################################################

githubRepositoryUrl="git@github.com:wataruian/helm-operator-get-started.git"
githubRepositoryBranch="master"
repositoryName="helm-operator-get-started"

# Get the parameter(s)
while [[ -n "$1" ]]; do
    case "$1" in
    --github-repository-url)
        githubRepositoryUrl="$2"
        shift
        ;;
    --github-repository-branch)
        githubRepositoryBranch="$2"
        shift
        ;;
    --repository-name)
        repositoryName="$2"
        shift
        ;;
    *)
        echo "Option $1 not recognized"
        exit 1
        ;;
    esac
    shift
done

if [[ -z "$githubRepositoryUrl" ]]; then
  echo "Github Repo Url not set!"
  exit 1
fi

if [[ -z "$githubRepositoryBranch" ]]; then
  echo "Github Repo Branch not set!"
  exit 1
fi

if [[ -z "$repositoryName" ]]; then
  echo "Repository Name not set!"
  exit 1
fi

if [[ ! -x "$(command -v kubectl)" ]]; then
    echo "kubectl not found"
    exit 1
fi

if [[ ! -x "$(command -v helm)" ]]; then
    echo "helm not found"
    exit 1
fi

helmReleaseName="flux-${repositoryName}"
githubDeployKeySecretName="${helmReleaseName}-git-deploy"
repositoryRootDirectory="$(git rev-parse --show-toplevel)"
temporaryDirectory="${repositoryRootDirectory}/temp"

echo ">>> Cluster bootstrap starting..."

echo ">>> Setting up temporary directory: ${temporaryDirectory}"
rm -rf ${temporaryDirectory} && mkdir ${temporaryDirectory}
echo ">>> Temporary directory setup done!"

echo ">>> Setting up chart repository: ${fluxCDChartUrl}"
helm repo add fluxcd ${fluxCDChartUrl}
helm repo update
echo ">>> Chart repository setup done!"

echo ">>> Setting up namespace: ${fluxNamespace}"
kubectl create namespace ${fluxNamespace} || echo "Namespace already exists. Continuing..."
echo ">>> Namespace setup done!"

echo ">>> Installing Flux"
echo "Git Repository: ${githubRepositoryUrl}"
echo "Git Repository Branch: ${githubRepositoryBranch}"
echo "Helm Release Name: ${helmReleaseName}"
helm upgrade -i ${helmReleaseName} fluxcd/flux --wait \
--set git.url=${githubRepositoryUrl} \
--set git.branch=${githubRepositoryBranch} \
--set git.path=${fluxDirectory} \
--set git.pollInterval=1m \
--set registry.pollInterval=1m \
--set sync.state=secret \
--set syncGarbageCollection.enabled=true \
--namespace ${fluxNamespace}
echo ">>> Flux installation done!"

echo ">>> Installing Helm Operator"
kubectl apply -f ${helmOperatorCrdUrl}
helm upgrade -i helm-operator fluxcd/helm-operator --wait \
--set git.ssh.secretName=${githubDeployKeySecretName} \
--set helm.versions=${helmVersion} \
--namespace ${fluxNamespace}
echo ">>> Helm Operator installation done!"

# wait until flux is able to sync with repo
counter=0
eventLogs=$(kubectl logs -n ${fluxNamespace} deployment/${helmReleaseName} | grep event=refreshed) \
&& isDeployKeyReady=true || isDeployKeyReady=false

while [[ $isDeployKeyReady == false ]]; do
  if [[ $counter -eq 0 ]]; then
    echo ">>> GitHub deploy key"
    kubectl -n ${fluxNamespace} logs deployment/${helmReleaseName} | grep identity.pub | cut -d '"' -f2
    echo ">>> Waiting on user to add above deploy key to Github with write access (${githubRepositoryUrl})"
  fi

  sleep 10

  eventLogs=$(kubectl logs -n ${fluxNamespace} deployment/${helmReleaseName} | grep event=refreshed) \
  && isDeployKeyReady=true || isDeployKeyReady=false

  counter=$(($counter + 1))
done

if [[ $counter -gt 0 ]]; then
  echo ">>> Github deploy key is ready"
fi

echo ">>> Cluster bootstrap done!"