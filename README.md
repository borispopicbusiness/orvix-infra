# Introduction

In this repository I store 
- infrastructure files
- Helm charts
- K8s manifests
- other infrastructure resources.

**For more information, inspect or check out develop branch.**

## Keycloak

Visit the following [link](https://github.com/borispopicbusiness/orvix-infra/tree/develop/environments/dev/keycloak)

## PostgreSQL and Patroni

Visit the following [link](https://github.com/borispopicbusiness/orvix-infra/blob/develop/helm/orvix-postgresql/README.MD)

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

### The pods

The currently running pods in the `dev` namespace':

```bash
NAME                              READY   STATUS    RESTARTS         AGE    IP               NODE      NOMINATED NODE   READINESS GATES
gateway-5ddddd6fc7-mlpch          1/1     Running   0                103m   10.244.208.116   k8s-wn1   <none>           <none>
keycloak-dev-keycloakx-0          1/1     Running   0 (3h55m ago)    14d    10.244.247.222   k8s-wn3   <none>           <none>
postgres-0                        1/1     Running   0 (3h53m ago)    45h    10.244.208.114   k8s-wn1   <none>           <none>
postgres-1                        1/1     Running   0 (3h55m ago)    45h    10.244.247.224   k8s-wn3   <none>           <none>
report-service-55b4df9875-d469v   1/1     Running   1                158m   10.244.166.180   k8s-wn2   <none>           <none>
report-service-55b4df9875-wqws4   1/1     Running   0                158m   10.244.247.226   k8s-wn3   <none>           <none>
user-service-6b4c66cd8b-xdvck     1/1     Running   1 (3h55m ago)    6d     10.244.247.225   k8s-wn3   <none>           <none>
user-service-6b4c66cd8b-zwfjs     1/1     Running   0 (3h55m ago)    6d     10.244.166.182   k8s-wn2   <none>           <none>
boris@boris-Nitro-AN515-58:~$ 
```

The environment currently contains:

    Gateway — a single instance responsible for routing incoming requests to the appropriate backend services.
    Keycloak — a single instance providing authentication and authorization services.
    PostgreSQL — two instances managed by Patroni, providing a high-availability PostgreSQL cluster.
    Report Service — two replicas for handling report-related requests.
    User Service — two replicas for handling user-related requests.

All currently listed pods are in the Running state and have passed their readiness checks.

### The services

The available services:

```bash
boris@boris-Nitro-AN515-58:~$ kubectl get services -n dev -o wide
NAME                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                    AGE     SELECTOR
gateway                           ClusterIP   10.105.131.124   <none>        8080/TCP                   6d19h   app.kubernetes.io/instance=gateway,app.kubernetes.io/name=gateway
keycloak-dev-keycloakx-headless   ClusterIP   None             <none>        80/TCP                     126d    app.kubernetes.io/instance=keycloak-dev,app.kubernetes.io/name=keycloakx
keycloak-dev-keycloakx-http       ClusterIP   10.111.243.82    <none>        9000/TCP,80/TCP,8443/TCP   126d    app.kubernetes.io/instance=keycloak-dev,app.kubernetes.io/name=keycloakx
postgres                          ClusterIP   None             <none>        5432/TCP                   45h     cluster-name=orvix-postgresql
postgres-primary                  ClusterIP   10.110.99.110    <none>        5432/TCP                   45h     cluster-name=orvix-postgresql,role=primary
postgres-replica                  ClusterIP   10.102.36.32     <none>        5432/TCP                   45h     cluster-name=orvix-postgresql,role=replica
report-service                    ClusterIP   10.105.28.78     <none>        8080/TCP                   160m    app.kubernetes.io/instance=report-service,app.kubernetes.io/name=report-service
user-service                      ClusterIP   10.102.178.31    <none>        8080/TCP                   6d      app.kubernetes.io/instance=user-service,app.kubernetes.io/name=user-service
boris@boris-Nitro-AN515-58:~$ 
```

The application services use ClusterIP Services for internal cluster communication:

    gateway — exposes the Gateway on port 8080.
    report-service — exposes the Report Service on port 8080.
    user-service — exposes the User Service on port 8080.
    keycloak-dev-keycloakx-http — exposes Keycloak's HTTP, HTTPS, and management ports.
    keycloak-dev-keycloakx-headless — headless Service used for Keycloak's StatefulSet networking.
    postgres-primary — provides access to the current PostgreSQL primary instance on port 5432.
    postgres-replica — provides access to the PostgreSQL replica instance on port 5432.
    postgres — headless Service exposing both PostgreSQL instances for StatefulSet/cluster networking.

### The service endpoints:

The endpoints associated with the services

```bash
boris@boris-Nitro-AN515-58:~$ kubectl get endpoints -n dev
NAME                              ENDPOINTS                                                     AGE
gateway                           10.244.208.116:8080                                           6d19h
keycloak-dev-keycloakx-headless   10.244.247.222:8080                                           126d
keycloak-dev-keycloakx-http       10.244.247.222:8443,10.244.247.222:9000,10.244.247.222:8080   126d
orvix-postgresql                  10.244.247.224:5432                                           3h57m
orvix-postgresql-config           <none>                                                        3h56m
postgres                          10.244.208.114:5432,10.244.247.224:5432                       45h
postgres-primary                  10.244.247.224:5432                                           45h
postgres-replica                  10.244.208.114:5432                                           45h
report-service                    10.244.166.180:8080,10.244.247.226:8080                       165m
user-service                      10.244.166.182:8080,10.244.247.225:8080                       6d
boris@boris-Nitro-AN515-58:~$ 
```

The `report-service` and `user-service` Services currently have two endpoints each, corresponding to their two running replicas.

The PostgreSQL Services expose endpoints according to the current Patroni cluster roles:

    postgres-primary points to the current primary PostgreSQL instance.
    postgres-replica points to the current replica.
    postgres exposes both PostgreSQL instances.

This allows clients to address the logical Kubernetes Service instead of depending directly on individual pod IP addresses.

### The Persistent Volume Claims:

```bash
boris@boris-Nitro-AN515-58:~$ kubectl get pvc -n dev
NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
data-keycloak-dev-keycloakx-0   Bound    pvc-48fac2d6-feb9-450e-ba2b-6c4ee456e4fc   1Gi        RWO            local-path     <unset>                 126d
postgres-data-postgres-0        Bound    pvc-3fc223a3-c580-4026-b7b2-eaec9c7e3030   10Gi       RWO            local-path     <unset>                 45h
postgres-data-postgres-1        Bound    pvc-411675ba-32bb-4b9c-a9b7-f0198abba237   10Gi       RWO            local-path     <unset>                 45h
boris@boris-Nitro-AN515-58:~$ 
```

The current persistent volume claims are:

    Keycloak — 1 GiB persistent volume using ReadWriteOnce.
    PostgreSQL primary — 10 GiB persistent volume using ReadWriteOnce.
    PostgreSQL replica — 10 GiB persistent volume using ReadWriteOnce.

All currently listed PVCs are in the Bound state and use the local-path StorageClass.

### The ingress

```bash
boris@boris-Nitro-AN515-58:~$ kubectl get ingresses -n dev
NAME                     CLASS     HOSTS                               ADDRESS         PORTS   AGE
gateway                  traefik   gateway.dev.k8s-svc.homelab         192.168.1.242   80      6d19h
keycloak-dev-keycloakx   traefik   keycloak-dev.keycloak.example.com   192.168.1.242   80      126d
boris@boris-Nitro-AN515-58:~$ 
```

The current ingress resources are:

    Gateway
        Host: gateway.dev.k8s-svc.homelab
        Ingress controller: traefik
        Address: 192.168.1.242
        Port: 80
    Keycloak
        Host: keycloak-dev.keycloak.example.com
        Ingress controller: traefik
        Address: 192.168.1.242
        Port: 80

The Gateway is therefore the external entry point for the application APIs, while Keycloak has a separate ingress for authentication and administration.

### The deployment

The current configuration uses one Gateway replica and two replicas each for the Report Service and User Service.

```bash
boris@boris-Nitro-AN515-58:~$ kubectl get deployments -n dev
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
gateway          1/1     1            1           6d19h
report-service   2/2     2            2           168m
user-service     2/2     2            2           6d
boris@boris-Nitro-AN515-58:~$ helm list -n dev
NAME              	NAMESPACE	REVISION	UPDATED                                 	STATUS  	CHART                 	APP VERSION
gateway           	dev      	3       	2026-09-06 10:40:06.207989529 +0200 CEST	deployed	gateway-0.1.0         	1.16.0     
keycloak-dev      	dev      	1       	2026-05-02 15:04:26.809911831 +0200 CEST	deployed	keycloakx-7.1.5       	26.4.5     
postgresql-patroni	dev      	1       	2026-09-04 14:42:19.949364361 +0200 CEST	deployed	orvix-postgresql-0.1.0	1.16.0     
report-service    	dev      	1       	2026-09-06 09:45:42.672107167 +0200 CEST	deployed	report-service-0.1.0  	1.16.0     
user-service      	dev      	1       	2026-08-31 12:22:38.381594116 +0200 CEST	deployed	user-service-0.1.0    	1.16.0     
boris@boris-Nitro-AN515-58:~$ 
```

Helm is used to manage the lifecycle and configuration of the application components and infrastructure deployed to the dev namespace.

### The StatefulSets

```bash
boris@boris-Nitro-AN515-58:~$ kubectl get statefulSet -n dev
NAME                     READY   AGE
keycloak-dev-keycloakx   1/1     126d
postgres                 2/2     45h
boris@boris-Nitro-AN515-58:~$ kubectl get replicaSets -n dev
NAME                        DESIRED   CURRENT   READY   AGE
gateway-5ddddd6fc7          1         1         1       6d19h
gateway-658458946f          0         0         0       119m
report-service-55b4df9875   2         2         2       170m
user-service-6b4c66cd8b     2         2         2       6d
boris@boris-Nitro-AN515-58:~$ 
```

The PostgreSQL StatefulSet consists of two stable, individually addressable pods:

    postgres-0
    postgres-1

Each PostgreSQL pod has its own persistent volume claim, allowing the database instances to retain their data independently of pod recreation.

ReplicaSets are created and managed by the application Deployments:

kubectl get replicasets -n dev

The currently active ReplicaSets are:

    gateway-5ddddd6fc7 — maintains one Gateway pod.
    report-service-55b4df9875 — maintains two Report Service pods.
    user-service-6b4c66cd8b — maintains two User Service pods.

The older gateway-658458946f ReplicaSet currently has zero replicas. It represents a previous Gateway deployment revision retained by Kubernetes for rollout and rollback purposes.

## Thew environment overview

                            ┌─────────────────┐
                            │     Traefik     │
                            │     Ingress     │ 
                            └────────┬────────┘
                                     │
                                     ▼
                            ┌─────────────────┐
                            │     Gateway     │
                            │    1 replica    │
                            └───────┬─────────┘
                                    │
                       ┌────────────┴────────────┐
                       │                         │
                       ▼                         ▼
                ┌──────────────┐          ┌──────────────┐
                │ User Service │          │Report Service│
                │  2 replicas  │          │  2 replicas  │ 
                └──────────────┘          └──────────────┘ 
                            ┌─────────────────┐ 
                            │     Keycloak    │
                            │    1 replica    │
                            └─────────────────┘ 
                            ┌─────────────────┐ 
                            │     Patroni /   │ 
                            │   PostgreSQL HA │ 
                            │     2 replicas  │ 
                            └─────────────────┘

This setup provides a Kubernetes-based development environment with service discovery through Kubernetes Services, external HTTP routing through Traefik, authentication through Keycloak, and PostgreSQL high availability through a two-node Patroni-managed cluster.

Although, my portfolio application, `Orvix`, is still in developement, I am planning to use the kubernetes cluster for its production deployment.

## CI/CD organization

For the CI/CD implementation, I use Jenkins for pipeline automation and ArgoCD for continuous delivery.  
This setup allows me to maintain up-to-date environments and streamline deployment processes across multiple services.
