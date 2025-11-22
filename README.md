# Introduction

In this repository I store infrastructure files, Helm charts, K8s manifests, etc.

**For more information, inspect or check out develop branch.**

## The k8s homelab

As you can see the homelab kubernetes cluster has one master node and three worker nodes:

    boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra$ kubectl get nodes
    NAME         STATUS   ROLES           AGE   VERSION
    k8s-master   Ready    control-plane   51d   v1.34.1
    k8s-wn1      Ready    <none>          51d   v1.34.1
    k8s-wn2      Ready    <none>          51d   v1.34.1
    k8s-wn3      Ready    <none>          51d   v1.34.1
    boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra$

Regarding the ram memory each worker node has 10GB of RAM memory while the master node has 5GB of RAM.
All nodes are actually QUEMU virtual machines:

    server@server-k8s-vms:~$ virsh list --all
    Id   Name     State
    ------------------------
    1    master   running
    2    wn1      running
    3    wn2      running
    4    wn3      running
    
    server@server-k8s-vms:~$

This cluster is used to test deployments, run microservices, and experiment with infrastructure configurations in a controlled environment.
Although, my portfolio application, Orvix, is still inactive, I am planning to use the kubernetes cluster for its production deployment.

## CI/CD organization

For the CI/CD implementation, I use Jenkins for pipeline automation and ArgoCD for continuous delivery.  
This setup allows me to maintain up-to-date environments and streamline deployment processes across multiple services.
