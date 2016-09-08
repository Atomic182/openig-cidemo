# Gatling example

This is an example of running a gatling test inside of Kubernetes.




Steps to run:
* Create your gatling test in perftest/IGPerftest.scala. 
* Build the docker image for gatling using ./build.sh. 
* Optionally push that image to a registry that your k8s cluster can access. 
For minikube, we just docker build direct to the cluster
* Run the gatling job:  ```kubectl create -f gatling-job.yaml```

This example uses a hostPath k8s volume to output the results. 

You can serve up the results files using:

```kubectl create -f web.yaml```

If you are using minikube, view the results with:

```minikube service web-results```

This will open up a web page with the gatling results.

# Notes:

For this example we assume OpenIG is running in the default namespace.
You may need to modify this example for your specific use case.

If you are running on a cloud k8s environment, hostPath volumes will not work - you
need to use a persistent volume claim.  



