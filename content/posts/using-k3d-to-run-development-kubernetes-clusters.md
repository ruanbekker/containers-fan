---
title: "Using k3d to Run Development Kubernetes Clusters"
date: 2022-03-07T06:00:00+02:00
draft: false
description: "This tutorial will demonstrate how to use k3d to spin up a kubernetes cluster, deploy a application to kubernetes and testing our application"
tags: ["k3d", "kubernetes", "traefik"]
categories: ["containers"]
---

In this tutorial, I will demonstrate how to provision a local development [kubernetes](https://kubernetes.io/) cluster using [k3d](https://k3d.io/v5.3.0/), we will define our cluster config with yaml, then deploy a basic hostname application to our kubernetes cluster, then clean up when we are done.

## What is k3d

k3d is a wrapper to run a kubernetes distribution called [k3s](https://github.com/rancher/k3s) on docker, which makes it really useful for local or edge environments. So [docker](https://docs.docker.com/get-docker/) will be a pre-requisite for this tutorial.

## Installing k3d

You can follow the [official documentation](https://k3d.io/v5.3.0/#installation) to install k3d, but for this scenario, I will be using [homebrew](https://brew.sh/) for MacOSx:

```bash
brew install k3d
```

To sucessfully install k3d, the output of:

```bash
k3d --version
```

Should output the following if you are using `v5.3.0`:

```
k3d version v5.3.0
k3s version v1.22.6-k3s1 (default)
```

## Basic Usage of k3d

To create a single server node kubernetes cluster on k3d, with the cluster name `containers-fan-cluster`, it's as simple as:

```bash
k3d cluster create containers-fan-cluster
```

You should see output something similar to:

```bash
INFO[0000] Prep: Network
INFO[0000] Created network 'k3d-containers-fan-cluster'
INFO[0000] Created image volume k3d-containers-fan-cluster-images
INFO[0000] Starting new tools node...
INFO[0001] Creating node 'k3d-containers-fan-cluster-server-0'
INFO[0006] Pulling image 'docker.io/rancher/k3d-tools:5.3.0'
INFO[0006] Pulling image 'docker.io/rancher/k3s:v1.22.6-k3s1'
INFO[0014] Starting Node 'k3d-containers-fan-cluster-tools'
INFO[0026] Creating LoadBalancer 'k3d-containers-fan-cluster-serverlb'
INFO[0030] Pulling image 'docker.io/rancher/k3d-proxy:5.3.0'
INFO[0037] Using the k3d-tools node to gather environment information
INFO[0039] Starting cluster 'containers-fan-cluster'
INFO[0039] Starting servers...
INFO[0039] Starting Node 'k3d-containers-fan-cluster-server-0'
INFO[0045] All agents already running.
INFO[0045] Starting helpers...
INFO[0045] Starting Node 'k3d-containers-fan-cluster-serverlb'
INFO[0052] Injecting records for hostAliases (incl. host.k3d.internal) and for 2 network members into CoreDNS configmap...
INFO[0054] Cluster 'containers-fan-cluster' created successfully!
INFO[0054] You can now use it like this:
kubectl cluster-info
```

As the output shows, we can run `kubectl cluster-info`, when we do this:

```bash
kubectl cluster-info
```

We get the output of:

```bash
Kubernetes control plane is running at https://0.0.0.0:64641
CoreDNS is running at https://0.0.0.0:64641/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://0.0.0.0:64641/api/v1/namespaces/kube-system/services/https:metrics-server:https/proxy

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
```

If you are wondering how this magic happens, k3d sets the kubernetes context to the config that the k3d client exported. We can verify this by running:

```bash
kubectl config get-contexts
```

Which should show something like the following:

```bash
CURRENT   NAME                         CLUSTER                      AUTHINFO                           NAMESPACE
*         k3d-containers-fan-cluster   k3d-containers-fan-cluster   admin@k3d-containers-fan-cluster
```

We can view the nodes in our cluster with `kubectl get nodes`, by running a detailed output like the following:

```bash
kubectl get nodes --output wide
```

Which should show something like the following:

```bash
NAME                                  STATUS   ROLES                  AGE     VERSION        INTERNAL-IP   EXTERNAL-IP   OS-IMAGE   KERNEL-VERSION     CONTAINER-RUNTIME
k3d-containers-fan-cluster-server-0   Ready    control-plane,master   4m35s   v1.22.6+k3s1   172.26.0.2    <none>        K3s dev    5.10.76-linuxkit   containerd://1.5.9-k3s1
```

We can now safely cleanup our cluster by deleting it:

```bash
k3d cluster delete containers-fan-cluster
```

## Bootstrapping Clusters with Config

We can use [config files](https://k3d.io/v5.3.0/usage/configfile/) with k3d in order to bootstrap our cluster the way we want it to be, without using a bunch of cli arguments.

We can define our `cluster.yml` with the following:

```yaml
apiVersion: k3d.io/v1alpha4
kind: Simple 
name: containers-fan-cluster2
servers: 1 
agents: 2 
kubeAPI: 
 hostIP: "127.0.0.1"
 hostPort: "6445"
ports:
 - port: 8080:80 
   nodeFilters:
     - loadbalancer
options:
 k3d: 
   wait: true 
   timeout: "60s"  
 k3s: 
   extraServerArgs: 
     - --tls-san=127.0.0.1.nip.io
   extraAgentArgs: [] 
 kubeconfig:
   updateDefaultKubeconfig: true 
   switchCurrentContext: true 
```

Which will ultimately provision a k3d cluster with the following:

- Create one server and two agents (one control-plane node, two worker nodes)
- Create a port mapping for the loadbalancer, host port 8080, container port 80
- Sets a custom tls san
- Update the default kubeconfig and switches it to the current context

We can provision our cluster with:

```bash
k3d cluster create --config cluster-latest.yml
```

This should output something like the following:

```bash
INFO[0000] Using config file cluster-latest.yml (k3d.io/v1alpha4#simple)
INFO[0000] portmapping '8080:80' targets the loadbalancer: defaulting to [servers:*:proxy agents:*:proxy]
INFO[0000] Prep: Network
INFO[0000] Created network 'k3d-containers-fan-cluster2'
INFO[0000] Created image volume k3d-containers-fan-cluster2-images
INFO[0000] Starting new tools node...
INFO[0000] Starting Node 'k3d-containers-fan-cluster2-tools'
INFO[0001] Creating node 'k3d-containers-fan-cluster2-server-0'
INFO[0001] Creating node 'k3d-containers-fan-cluster2-agent-0'
INFO[0001] Creating node 'k3d-containers-fan-cluster2-agent-1'
INFO[0001] Creating LoadBalancer 'k3d-containers-fan-cluster2-serverlb'
INFO[0001] Using the k3d-tools node to gather environment information
INFO[0002] Starting cluster 'containers-fan-cluster2'
INFO[0002] Starting servers...
INFO[0002] Starting Node 'k3d-containers-fan-cluster2-server-0'
INFO[0007] Starting agents...
INFO[0007] Starting Node 'k3d-containers-fan-cluster2-agent-0'
INFO[0007] Starting Node 'k3d-containers-fan-cluster2-agent-1'
INFO[0017] Starting helpers...
INFO[0017] Starting Node 'k3d-containers-fan-cluster2-serverlb'
INFO[0023] Injecting records for hostAliases (incl. host.k3d.internal) and for 4 network members into CoreDNS configmap...
INFO[0026] Cluster 'containers-fan-cluster2' created successfully!
INFO[0026] You can now use it like this:
kubectl cluster-info
```

To see if our nodes are ready, we can look at the `STATUS` column, and we should see `Ready` on all the nodes, run:

```bash
kubectl get nodes --output wide
```

And in my case the output displays:

```bash
NAME                                   STATUS   ROLES                  AGE   VERSION        INTERNAL-IP   EXTERNAL-IP   OS-IMAGE   KERNEL-VERSION     CONTAINER-RUNTIME
k3d-containers-fan-cluster2-agent-0    Ready    <none>                 55s   v1.22.6+k3s1   172.27.0.3    <none>        K3s dev    5.10.76-linuxkit   containerd://1.5.9-k3s1
k3d-containers-fan-cluster2-agent-1    Ready    <none>                 55s   v1.22.6+k3s1   172.27.0.4    <none>        K3s dev    5.10.76-linuxkit   containerd://1.5.9-k3s1
k3d-containers-fan-cluster2-server-0   Ready    control-plane,master   62s   v1.22.6+k3s1   172.27.0.2    <none>        K3s dev    5.10.76-linuxkit   containerd://1.5.9-k3s1
```

## Deploying a Web Application to our Cluster

Now that our nodes are running we can deploy a basic web application which we will define in our `deployment.yml`:

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: hostname-service
spec:
  selector:
    app: hostname
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
      name: web
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hostname-ingress
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - host: hostname.127.0.0.1.nip.io
    http:
      paths:
      - pathType: Prefix
        path: "/"
        backend:
          service:
            name: hostname-service
            port:
              number: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: hostname
  name: hostname
spec:
  replicas: 3
  selector:
    matchLabels:
      app: hostname
  template:
    metadata:
      labels:
        app: hostname
    spec:
      containers:
      - name: hostname
        image: ruanbekker/hostname:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP
```

In our deployment we are deploying the following:

- a Deployment of a container with three replicas of the image `ruanbekker/hostname:latest` and specifying the container port of `8080`
- a Service named `hostname-service` with the listenting port of `80` and translating to the target port of `8080` which is specified in the deployment
- a Ingress which maps the hostname `hostname.127.0.0.1.nip.io` and a pathPrefix of `/` to the `hostname-service` on port `80`

To run our deployment:

```bash
kubectl apply -f deployment.yml
```

Which should output something like the following:

```bash
service/hostname-service created
ingress.networking.k8s.io/hostname-ingress created
deployment.apps/hostname created
```

We can now verify that the deployment has reached it's desired state:

```bash
kubectl get deployments --output wide
```

Which outputs:

```bash
NAME       READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES                       SELECTOR
hostname   3/3     3            3           11s   hostname     ruanbekker/hostname:latest   app=hostname
```

We can view our pods and also the nodes where these pods runs on by using:

```bash
kubectl get pods --output wide
```

Which outputs:

```bash
NAME                        READY   STATUS    RESTARTS   AGE   IP          NODE                                   NOMINATED NODE   READINESS GATES
hostname-5cc54d8fcd-fsvg4   1/1     Running   0          19s   10.42.0.6   k3d-containers-fan-cluster2-server-0   <none>           <none>
hostname-5cc54d8fcd-wv57q   1/1     Running   0          19s   10.42.2.8   k3d-containers-fan-cluster2-agent-1    <none>           <none>
hostname-5cc54d8fcd-hnsrz   1/1     Running   0          19s   10.42.1.7   k3d-containers-fan-cluster2-agent-0    <none>           <none>
```

To view our ingresses:

```bash
kubectl get ingress --output wide
```

Which outputs the following:

```bash
NAME               CLASS    HOSTS                       ADDRESS                            PORTS   AGE
hostname-ingress   <none>   hostname.127.0.0.1.nip.io   172.27.0.2,172.27.0.3,172.27.0.4   80      25s
```

And lastly our services:

```
kubectl get services --output wide
```

Which outputs the following:

```bash
NAME               TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE   SELECTOR
kubernetes         ClusterIP   10.43.0.1      <none>        443/TCP   54m   <none>
hostname-service   ClusterIP   10.43.149.31   <none>        80/TCP    36s   app=hostname
```

## Testing our Web Application

Our application is a basic Go web application that returns the hostname of the environment where it's running on. Since we have 3 replicas for our deployment, each request should round robin between 3 pods and return three different hostnames.

Our first request:

```bash
curl http://hostname.127.0.0.1.nip.io:8080
```

Which returns:

```
Hostname: hostname-5cc54d8fcd-hnsrz
```

The second request returns:

```
Hostname: hostname-5cc54d8fcd-wv57q
```

The third request returns:

```
Hostname: hostname-5cc54d8fcd-fsvg4
```

And our fourth request should return the same as our first request:

```
Hostname: hostname-5cc54d8fcd-hnsrz
```

## Cleanup

To delete the cluster you can use `k3d cluster delete <name-of-the-cluster>` or if you want to delete all the k3d managed clusters:

```
k3d cluster delete --all
```

## Thank You

Thanks for reading, if you like my content, check out my **[website](https://ruan.dev)** or follow me at **[@ruanbekker](https://twitter.com/ruanbekker)** on Twitter.

