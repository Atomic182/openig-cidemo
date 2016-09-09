# Demonstrate how to deploy OpenIG to Kubernetes from a Jenkins CI pipeline 

##Warning

**This code is not supported by ForgeRock and it is your responsibility to verify that the software is suitable and safe for use.**

# Overview 

This project includes a Jenkins pipeline file  (Jenkinsfile) which contains instructions on how to build an OpenIG image 
and deploy it to a Kubernetes cluster. 

To use this you need:
* Jenkins CI, version 2.x - as it needs the multi branch pipeline feature. If you are on a mac, you
can install jenkins using  ```brew install jenkins```
* The docker and kubectl commands need to be available to Jenkins as it will use these commands to build and deploy images 
* Access to the OpenIG base image (openig). See https://stash.forgerock.org/projects/DOCKER/repos/docker/browse

You should have a good working knowledge of Docker and Kubernetes to complete this example. 

The sample OpenIG deployment demonstrates social login using Google. You 
must create OpenID connect credentials in the Google Developer Console. 
https://console.cloud.google.com/apis/credentials



# Stage 1

* Fork and clone this repository 
* Copy env-COPYME.sh to env.sh, and enter your Google OIDC credentials here. This 
sample demonstrates how to keep secrets such as credentials from being checked in to git. The file env.sh 
is in .gitignore
* Ensure minikube is running. 
* Build the base *forgerock/openig* image from the ForgeRock Docker repo at https://stash.forgerock.org/projects/DOCKER/repos/docker/ 
* For example, for minikube, assuming you have cloned the above repo:
```
cd docker
docker build -t forgerock/openig  openig
```

* It is recommended that you create an ingress controller for minikube. See create-ingress.sh. 
(In the future minikube is expected to make this easier - this step may not be required)
* Run 

```
./deploy.sh
```

The above shell script will deploy the sample application to the *default* namespace in kubernetes.

* Add an entry in your /etc/hosts of the form 

```
192.168.34.5  openig.default.test.com 
```


The ip address above is the ip returned by ```minikube ip```

You should now be able to bring up the demo application:

http://openig.default.test.com 

Test the OpenID connect functionality:

http://openig.default.test.com/openid  



# Stage 2

This stage will setup Jenkins to automatically build a new docker image and push it to Kubernetes. 

* Create a "multi branch pipeline" job in Jenkins that uses git or github as a source 
* Make sure Jenkins has access to the docker and kubectl commands. On a mac
 run  ```eval $(minikube docker-env);  jenkins``` to start jenkins. This ensures the 
 shell environment inherited by jenkins is configured to use your minikube cluster. 
* Create a username and password secret credential in Jenkins called *oidc-secret*. The
 username contains your google client id, and the password holds the client secret.
 The Jenkins pipeline uses this to create *env.sh*. See the Jenkinsfile for details.
* The build is configured to use the git branch name as the namespace to deploy to. For example,
if you are on a git branch called "my-test-feature", it will get deployed to a k8s namespace
called "my-test-feature". 
* The build also uses the branch name to qualify the ingress. An ingress 
hostname of the form  openig.BRANCH_NAME.test.com is created. 
Assuming you are using the "master" branch, add the following to /etc/hosts


```
192.168.34.5  openig.default.test.com openig.master.test.com
```

Using namespaces and ingress hostnames enables you to deploy
separate instances of OpenIG to the same Kubernetes cluster, and
to keep those instances isolated. 

# Development flow


* Use deploy.sh to rapidly test new features without having to commit every change to git.
* When you want to automate the deployment using Jenkins, create a feature branch
* The OpenIG configuration is in openig/config and is used to create an immutable OpenIG Docker image
* When the branch is pushed, Jenkins will pick it up and start to run the pipeline defined in ./Jenkinsfile (note:
Jenkins currently has a bug (https://issues.jenkins-ci.org/browse/JENKINS-35310 ) where build triggers can not be saved). 
You must manually trigger the build in the Jenkins UI.
* deploy.sh invokes *docker build* to create a new child image which is configured according to openig/config
* The image is optionally pushed to a registry. 
* kubectl commands are issued to push the new image to Kubernetes. If an old image already exists, it will be replaced by
the new image using a rolling deployment. Deployments allow for rolling upgrades and roll back. 

# Production and Canary

* The "production" namespace is treated as special. It will cause a load balancer ingress to be created so
that the image becomes reachable from outside the cluster. It will also deploy
multiple copies of the OpenIG container by specifying a replica count in the deployment
* The canary branch is used to test a canary build. The concept
is to use a k8s deployment, and roll out a single instance to production. This instance
will receive a fraction of the traffic, and can be used to ensure the new build is stable
and can be promoted to production.

The canary deployment works by creating a new deployment (openig-canary) that 
gets deployed alongside the production deployment (openig). The production 
deployment will have several replicas (let's say 5), while the canary will
have a single replica. You can play with this blend by adjusting the replica count for each deployment. 

Both deployments are selected by the service definition and/or the ingress
through the use of labels.  For example, if the ingress selects for
"openig" - it will find pods for both the canary and the production instances. 
You can change this behavior through a selector expression. This can be
 used to selectively turn canary behavior on or off. 
 
You can try the /hello page  [http://openig.production.test.com/hello ]
to view the instance you are connecting to. This page will print
the instance name as part of the host name - so you should see it change from production to
canary if you get load balanced to a different backend. 

Note that ingress controllers generally try to use sticky load balancing to a
backend -so you wont see this in a browser.  Try using curl instead,
and running it many times until you get the canary instance:

```
curl http://openig.production.test.com/hello 
curl http://openig.production.test.com/hello 


```


 


# Ingress Alternatives

To reach other namespace instances you can use kubectl port-forward to forward a local laptop port
to the cluster.  For example:

```
kubectl get pods --all-namespaces
kubectl port-forward --namespace=test openig-d86gh7 8080:8080
```


If you are using minikube you can use:

```
minikube service openig -n git-branch-name
```

This opens a browser window to the IG service. 

**Note:** IG does not like to be behind a proxy server where
the request context path is modified (i.e. it wants to be at the root). In addition,
the callback URLs for the OIDC example need to match those configured in the Google developer console. 
You will have to adjust your IG configuration appropriately. You may 
wish to use an ingress even for dev branches, so you get the root context
with no url prefix.


See openig/README.md for more information on the sample IG configuration


# Tips

* If you are doing development on minikube, rather than push 
to a registry, and then have k8s download the image again, it
is easier to docker build directly to the docker instance
used by k8s in minikube.  Set the imagePullPolicy appropriately in
k8s/dev/. This is the way deploy.sh currently works. 
* The k8s dashboard is helpful to view logs, etc. On minikube open 
with:
```
minikube dashboard
```


# Fun things to try:

### Change the number of replicas

In the k8s dashboard, edit the openig deployment object, and
change the number of replicas. You will see new pods created.

### Answer the question: What changed between the current and previous release?

git diff HEAD^ HEAD
 
### Rollbacks 

Show deployment history:

```
kubectl --namespace=master rollout history deployment/openig
```

Show a revision: 
```
kubectl --namespace=master rollout history deployment/openig --revision=20
```

Undo a rollout (optionally specify --revision=) and revert back to
a previous release:

```
kubectl --namespace=master rollout undo deployment/openig
```


### Autoscale your deployment:

Note: this requires heapster to be running on k8s - and will not work 
out of the box on minikube

```
kubectl --namespace=master autoscale deployment openig --min=1 --max=4 --cpu-percent=10 
```
Delete autoscaling: 
```
kubectl --namespace=master delete hpa openig
```




### Tips

To clean up all the openig-custom images in docker:

docker rmi $(docker images  openig-custom -q)

(Note: this is dangerous, but if you want to force image
deletion use rmi -f )


# Todo:

OpenIG:

* Expand example to include the sample app described in the OpenIG gateway guide 
* Parameterize OpenIG config further

k8s:

* Get jenkins running in k8s - so the example can self bootstrap
* Test on GKE







