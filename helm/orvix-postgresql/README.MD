# The set-up of PostgreSQL and Patroni

## The Documentation

- The Patroni documentation, [here](https://patroni.readthedocs.io/en/latest/README.html)
- The repository where useful Patroni yaml configuration files can be found, [here](https://patroni.readthedocs.io/en/latest/README.html)

## The docker image

The PostgreSQL and Patroni Docker image is available online and can be pulled with:

```bash
docker pull borispopicdev/postgresql-patroni
```

The chart also contains a Dockerfile that can be used to build the image locally.
After building the image, it can be tagged and pushed to Docker Hub:
```bash
docker build -t postgresql-patroni:latest .
docker tag postgresql-patroni:latest borispopicdev/postgresql-patroni:latest
docker push borispopicdev/postgresql-patroni:latest
```

## The architecture of the database cluster

The database cluster consists of two PostgreSQL instances managed by Patroni. Both instances are deployed as pods belonging to the same Kubernetes StatefulSet, which provides stable identities for the individual cluster members.

The cluster has a primary PostgreSQL instance and a replica PostgreSQL instance:

                        PostgreSQL Cluster
                        ┌─────────────────┐
                        │     Patroni     │ 
                        │ Cluster Manager │
                        └────────┬────────┘
                                 │ 
                  ┌──────────────┴───────────────┐ 
                  │                              │ 
                  ▼                              ▼ 
            ┌─────────────┐                ┌─────────────┐ 
            │ postgres-0  │                │ postgres-1  │ 
            │ PRIMARY     │───────────────►│ REPLICA     │ 
            │ PostgreSQL  │ replication    │ PostgreSQL  │ 
            └─────────────┘                └─────────────┘
Patroni is responsible for determining which PostgreSQL instance is the current primary and for managing failover. If the primary becomes unavailable, Patroni can promote the replica to primary.

## About the helm repository

I created a dedicated Helm chart for PostgreSQL and Patroni. I spent some time exploring Patroni and its integration with PostgreSQL, including how Patroni manages the PostgreSQL cluster and performs primary-replica failover.

I will not repeat the overall architecture here, as it is described in the corresponding architecture documentation.

The Helm chart defines a StatefulSet with a replica count of 2. In addition, several Kubernetes resources are defined: the required RBAC resources, a headless Service, and two ClusterIP Services.

The headless Service provides stable DNS identities for the PostgreSQL StatefulSet members, while the two ClusterIP Services expose the current primary and replica instances based on their Patroni-managed roles.

Together, these three Services provide the Kubernetes networking and service-discovery layer required for Patroni to manage primary-replica switching and allow applications to connect to the current primary without depending on an individual pod IP.

## The kubernetes services

The cluster uses three Services:

    - postgres — a headless Service used to provide stable DNS identities for the individual StatefulSet members.
    - postgres-primary — a ClusterIP Service that points to the PostgreSQL instance currently running as the primary.
    - postgres-replica — a ClusterIP Service that points to the PostgreSQL instance currently running as a replica.

The headless Service allows the individual members to be addressed using stable DNS names such as:

    - postgres-0.postgres
    - postgres-1.postgres

The ClusterIP Services provide role-based access rather than instance-based access. Applications should therefore connect to postgres-primary instead of connecting directly to a specific PostgreSQL pod.

For example:

                            Application 
                                 │ 
                                 │ postgres-primary:5432 
                                 ▼ 
                        ┌───────────────────┐ 
                        │ postgres-primary  │ 
                        │ ClusterIP         │ 
                        └─────────┬─────────┘ 
                                  │ 
                                  ▼ 
                           Current primary

### The primary-replica failover

The primary and replica roles are not permanently assigned to postgres-0 and postgres-1. Patroni manages these roles dynamically.

For example, under normal operation:

    - postgres-0 → PRIMARY
    - postgres-1 → REPLICA

    - postgres-primary → postgres-0
    - postgres-replica → postgres-1

If postgres-0 becomes unavailable, Patroni can promote postgres-1:

    - postgres-0 → DOWN
    - postgres-1 → PRIMARY

    - postgres-primary → postgres-1

The pod IP address does not move from one pod to another. Instead, Kubernetes updates the endpoints of the role-based Services according to the labels maintained by Patroni.

This allows applications to continue using the same database hostname:

    postgres-primary:5432

without needing to know which PostgreSQL pod is currently the primary.

When the failed instance is recreated, it can rejoin the cluster as a replica and synchronize its data from the current primary.

This separation between **individual pod identity**, **PostgreSQL role**, and **Kubernetes Service identity** is an important part of the cluster architecture. StatefulSet DNS provides stable identities for the cluster members, Patroni manages PostgreSQL roles and failover, and Kubernetes Services provide stable endpoints for applications.

## The post-installation overview

After installing the PostgreSQL and Patroni Helm chart, the first step is to verify that all components of the database cluster have been created successfully and that both PostgreSQL instances are running.

The StatefulSet should contain two PostgreSQL pods:

    - postgres-0
    - postgres-1

Both pods should eventually reach the `Running` and `Ready` state.

The Patroni roles can be verified using:

```bash
kubectl exec -n dev postgres-0 -- patronictl -c /tmp/patroni.yaml list
```
The output shows one instance with the Leader role and the other with the Replica role.

```bash
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra/helm/orvix-postgresql$ kubectl exec -n dev postgres-0 -- patronictl -c /tmp/patroni.yaml list
+ Cluster: orvix-postgresql (7681659639818051617) --+----+-------------+-----+------------+-----+
| Member     | Host           | Role    | State     | TL | Receive LSN | Lag | Replay LSN | Lag |
+------------+----------------+---------+-----------+----+-------------+-----+------------+-----+
| postgres-0 | 10.244.208.108 | Leader  | running   |  1 |             |     |            |     |
| postgres-1 | 10.244.247.214 | Replica | streaming |  1 |   0/304F990 |   0 |  0/304F990 |   0 |
+------------+----------------+---------+-----------+----+-------------+-----+------------+-----+
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra/helm/orvix-postgresql$ 
```

The kubernetes pods can be inspected using the the standard kubectl pod commands. Here, we can see that the pods have been successfully created and are running.

```bash
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra/helm/orvix-postgresql$ kubectl get pods -n dev
NAME                            READY   STATUS    RESTARTS         AGE
gateway-5ddddd6fc7-fmsfx        1/1     Running   5 (4h37m ago)    4d22h
keycloak-dev-keycloakx-0        1/1     Running   13 (4h39m ago)   12d
postgres-0                      1/1     Running   0                7m32s
postgres-1                      1/1     Running   0                7m5s
user-service-6b4c66cd8b-xdvck   1/1     Running   4 (4h39m ago)    4d2h
user-service-6b4c66cd8b-zwfjs   1/1     Running   4 (4h39m ago)    4d2h
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra/helm/orvix-postgresql$ 
```

The kubernetes services can be identified and briefly inspected by executing:

```bash
kubectl get services -n dev
```

```bash
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra/helm/orvix-postgresql$ kubectl get services -n dev
NAME                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                    AGE
gateway                           ClusterIP   10.105.131.124   <none>        8080/TCP                   4d22h
keycloak-dev-keycloakx-headless   ClusterIP   None             <none>        80/TCP                     124d
keycloak-dev-keycloakx-http       ClusterIP   10.111.243.82    <none>        9000/TCP,80/TCP,8443/TCP   124d
postgres                          ClusterIP   None             <none>        5432/TCP                   8m11s
postgres-primary                  ClusterIP   10.110.99.110    <none>        5432/TCP                   8m11s
postgres-replica                  ClusterIP   10.102.36.32     <none>        5432/TCP                   8m11s
user-service                      ClusterIP   10.102.178.31    <none>        8080/TCP                   4d2h
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra/helm/orvix-postgresql$ 
```

The installation creates three Services:

    - postgres
    - postgres-primary
    - postgres-replica

The postgres Service is headless and provides stable DNS identities for the StatefulSet members. The postgres-primary and postgres-replica Services expose the instances according to their current Patroni roles.

The current Service endpoints:

```bash
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra/helm/orvix-postgresql$ kubectl get endpoints -n dev
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
NAME                              ENDPOINTS                                                     AGE
gateway                           10.244.208.97:8080                                            4d22h
keycloak-dev-keycloakx-headless   10.244.247.202:8080                                           124d
keycloak-dev-keycloakx-http       10.244.247.202:8443,10.244.247.202:9000,10.244.247.202:8080   124d
orvix-postgresql                  10.244.208.108:5432                                           8m21s
orvix-postgresql-config           <none>                                                        8m25s
postgres                          10.244.208.108:5432,10.244.247.214:5432                       8m43s
postgres-primary                  10.244.208.108:5432                                           8m43s
postgres-replica                  10.244.247.214:5432                                           8m43s
user-service                      10.244.166.164:8080,10.244.247.205:8080                       4d2h
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra/helm/orvix-postgresql$ 
```

Both PostgreSQL pods have their own PersistentVolumeClaim (PVC), with one PVC dedicated to each pod. This ensures that each PostgreSQL instance has its own persistent storage:

```bash
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra/helm/orvix-postgresql$ kubectl get pvc -n dev
NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
data-keycloak-dev-keycloakx-0   Bound    pvc-48fac2d6-feb9-450e-ba2b-6c4ee456e4fc   1Gi        RWO            local-path     <unset>                 124d
postgres-data-postgres-0        Bound    pvc-3fc223a3-c580-4026-b7b2-eaec9c7e3030   10Gi       RWO            local-path     <unset>                 9m15s
postgres-data-postgres-1        Bound    pvc-411675ba-32bb-4b9c-a9b7-f0198abba237   10Gi       RWO            local-path     <unset>                 8m48s
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra/helm/orvix-postgresql$ 
```

## The connectivity testing:

The final verification should confirm that applications can connect through postgres-primary and that Patroni is able to maintain the primary-replica relationship.

For example, a local connection can be established using port forwarding:

```bash
kubectl port-forward -n dev svc/postgres-primary 5432:5432
```
The PostgreSQL client can then connect through:
```bash
psql -h localhost -p 5432 -U postgres
```
The connection successfully established:

```bash
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra/helm/orvix-postgresql$ psql -h localhost -p 5433 -U postgres
Password for user postgres: 
psql (16.15 (Ubuntu 16.15-0ubuntu0.24.04.1), server 17.4 (Debian 17.4-1.pgdg120+2))
WARNING: psql major version 16, server major version 17.
         Some psql features might not work.
Type "help" for help.

postgres=# 
```
**The important point is that applications should **use the postgres-primary** Service rather than a specific PostgreSQL pod. This allows the Kubernetes Service to follow the current Patroni primary during a failover.**

As you can see the database `orvix-dev` is created and ready. The name prefix is actually the name of the k8s namespace that the database is run in.

```bash
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-user$ kubectl exec -it -n dev postgres-0 -- psql -U postgres -d postgres -W -c "SELECT datname FROM pg_database;"
Password: 
  datname  
-----------
 postgres
 orvix-dev
 template1
 template0
(4 rows)

boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-user$ 
```