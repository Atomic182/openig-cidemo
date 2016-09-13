#!/usr/bin/env bash
# Deployment script to build a docker image and deploy to Kubernetes
# The idea here is to simplify the Jenkinsfile to just
# those things that are unique to the automated build process
# By creating a seperate deploy script you can test deployment
# without needing to commit each change to git

# source any private env vars
# Things like secrets can get set in this file. This file is not checked in to git
source env.sh


# Environment variables that are expected to get set by Jenkins - but will default if not set

BRANCH_NAME=${BRANCH_NAME:-default}
# We default build number to the timestamp in seconds and use this in the docker image tag
# If you use the same build number each time, k8s will think the image is the same and will not roll out a new one
# When a deployment is used.
BUILD_NUMBER=${BUILD_NUMBER:-`date +%s`}


# If command line args are supplied - $1 is the branch name
if [ "$#" -eq 1 ]; then
   BRANCH_NAME=$1
fi

# Default k8s namespace is the git branch
NAMESPACE=${BRANCH_NAME}

# Env vars use to parameterize deployment
APP_NAME=openig
# Name of the app image to build
IMAGE="${APP_NAME}-custom:${BRANCH_NAME}.${BUILD_NUMBER}"

TMPDIR="/tmp/openig"

mkdir -p $TMPDIR

# If you are building on GKE and want to push to the gcr registry, use this
#GC="gcloud"
# otherwise, use this
GC=""


echo "Building Docker image $IMAGE"

$GC docker build -t $IMAGE openig

# To push to registry uncomment this
# If you are doing local development, you probably dont need to push since you
# will build direct to docker in k8s
#$GC docker push $IMAGE

# shortcut
kc="kubectl --namespace=${NAMESPACE}"


# Generate a keystore for OpenIG
function create_keystore_secret {
 echo "creating keystore secret"
   rm -f  $TMPDIR/keystore.jks
   keytool -genkey -alias jwe-key -keyalg rsa -keystore ${TMPDIR}/keystore.jks -storepass changeit \
         -keypass changeit -dname "CN=openig.example.com,O=Example Corp"
   $kc create secret generic openig --from-file=${TMPDIR}/keystore.jks
}

# Create all the generic type secrets here...
# Right now this is the client id / secret for the social login example
function create_secrets {
  $kc delete secret ig-secrets
  $kc create secret generic ig-secrets \
      --from-literal=client-id=${CLIENT_ID} \
      --from-literal=client-secret=${CLIENT_SECRET}
}

# run all the template expansions on our yaml and then deploy
function do_template {
   for file in "$@"
   do
      echo "templating $file"
      sed -e "s#IMAGE_TEMPLATE#${IMAGE}#" -e "s#NAMESPACE_TEMPLATE#${NAMESPACE}#" $file  > $TMPDIR/out.yaml
      kubectl --namespace="${NAMESPACE}" apply -f $TMPDIR/out.yaml
   done
}

# Canary does not deploy to a new namespace..
if [ "${NAMESPACE}"  != "canary" ];
then

   echo "Creating namespace ${NAMESPACE} if it does not exist"
   kubectl get ns ${NAMESPACE} || kubectl create ns ${NAMESPACE}

   # if openig keystore secret does not exist, create it
   $kc get secret openig || create_keystore_secret

   # if generic secrets do not exist, create it
   create_secrets


   echo "Creating/updating services"
   $kc apply -f k8s/services
fi


echo "Creating/updating deployments"

case $NAMESPACE in
production)
   do_template k8s/production/*.yaml
   ;;
canary)
   echo "Doing a canary deployment"
   # reset namespace - because canary goes to production
   NAMESPACE="production"
   do_template k8s/canary/*.yaml
   ;;
*)
   do_template k8s/dev/*yaml
   ;;
esac


# clean up
rm -fr $TMPDIR

