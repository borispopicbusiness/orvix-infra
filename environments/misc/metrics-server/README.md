# Adding the Metrics server to the Kubernetes cluster

## Introduction

Metrics Server collects resource usage metrics from the Kubernetes nodes and makes them available through the Kubernetes Metrics API.

It allows us to use commands such as:

```bash
kubectl top nodes
```

and:

```bash
kubectl top pods
```
to view CPU and memory usage.

## Installation

Installing Metrics server is straightforward. We can install it by applying the official Metrics Server manifest.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

After installation, verify that the Metrics Server pod is running:

```bash
kubectl get pods -n kube-system | grep metrics-server
```

The putput looks like this:

```bash
boris@boris-Nitro-AN515-58:~$ kubectl get pods -n kube-system | grep metrics-server
metrics-server-7c5fdf4664-dpkkb         0/1     Running   0                 147m
boris@boris-Nitro-AN515-58:~$ 
```

### Patching

By default, Metrics Server verifies the TLS certificate presented by the kubelet on each node.

In our Kubernetes cluster, the kubelet certificates do not contain the nodes' IP addresses as IP Subject Alternative Names (SANs). As a result, Metrics Server cannot verify the kubelet certificates and fails to collect metrics.

We can configure Metrics Server to skip kubelet certificate verification by adding the `--kubelet-insecure-tls` argument:

```bash
kubectl -n kube-system patch deployment metrics-server --type='json' -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'
```

After applying the patch, Kubernetes will create a new Metrics Server pod with the updated configuration.

Verify that the new pod is running:

```bash
kubectl get pods -n kube-system | grep metrics-server
```

```bash
boris@boris-Nitro-AN515-58:~$ kubectl get pods -n kube-system | grep metrics-server
metrics-server-7c5fdf4664-dpkkb         1/1     Running   0                 147m
boris@boris-Nitro-AN515-58:~$ 
```

## Testing

To test whether Metrics Server is successfully collecting resource usage metrics from the control-plane and worker nodes, use:

```bash
kubectl top nodes
kubectl top pods -n dev
kubectl top pods -A
```
The results of the commands:

```bash
boris@boris-Nitro-AN515-58:~$ kubectl top nodes
NAME         CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%   
k8s-master   357m         17%    1848Mi          38%       
k8s-wn1      145m         7%     1473Mi          14%       
k8s-wn2      142m         7%     1708Mi          17%       
k8s-wn3      127m         6%     2224Mi          22%       
boris@boris-Nitro-AN515-58:~$ 
```

```bash
boris@boris-Nitro-AN515-58:~$ kubectl top pods -A
NAMESPACE            NAME                                      CPU(cores)   MEMORY(bytes)   
dev                  gateway-5ddddd6fc7-mlpch                  3m           269Mi           
dev                  keycloak-dev-keycloakx-0                  9m           641Mi           
dev                  postgres-0                                2m           131Mi           
dev                  postgres-1                                2m           133Mi           
dev                  report-service-55b4df9875-d469v           3m           221Mi           
dev                  report-service-55b4df9875-wqws4           3m           272Mi           
dev                  user-service-6b4c66cd8b-xdvck             4m           232Mi           
dev                  user-service-6b4c66cd8b-zwfjs             3m           259Mi           
kube-system          calico-kube-controllers-f547f75-fmqvx     3m           55Mi            
kube-system          calico-node-bmvcq                         42m          139Mi           
kube-system          calico-node-h2k2g                         44m          131Mi           
kube-system          calico-node-tqk2v                         42m          133Mi           
kube-system          calico-node-wqmdt                         43m          139Mi           
kube-system          coredns-69bf469964-lp27v                  4m           72Mi            
kube-system          coredns-69bf469964-tzvvg                  5m           71Mi            
kube-system          etcd-k8s-master                           56m          97Mi            
kube-system          kube-apiserver-k8s-master                 101m         408Mi           
kube-system          kube-controller-manager-k8s-master        32m          128Mi           
kube-system          kube-proxy-9jr8t                          1m           56Mi            
kube-system          kube-proxy-fqc5g                          1m           56Mi            
kube-system          kube-proxy-kj85p                          2m           56Mi            
kube-system          kube-proxy-z6tsm                          2m           56Mi            
kube-system          kube-scheduler-k8s-master                 17m          64Mi            
kube-system          metrics-server-7c5fdf4664-dpkkb           6m           19Mi            
local-path-storage   local-path-provisioner-579c76b5f9-56ngm   1m           46Mi            
metallb-system       metallb-controller-68448f74cd-2vwmf       3m           52Mi            
metallb-system       metallb-speaker-4jg7f                     13m          117Mi           
metallb-system       metallb-speaker-5hwwq                     16m          117Mi           
metallb-system       metallb-speaker-br9bt                     12m          118Mi           
metallb-system       metallb-speaker-gnh86                     15m          117Mi           
sealed-secrets       sealed-secrets-65f4b8cd84-4n48n           1m           47Mi            
traefik              traefik-75485c459f-kztgh                  1m           128Mi           
boris@boris-Nitro-AN515-58:~$ kubectl top pods -n dev
NAME                              CPU(cores)   MEMORY(bytes)   
gateway-5ddddd6fc7-mlpch          3m           269Mi           
keycloak-dev-keycloakx-0          7m           641Mi           
postgres-0                        2m           131Mi           
postgres-1                        2m           133Mi           
report-service-55b4df9875-d469v   3m           221Mi           
report-service-55b4df9875-wqws4   3m           272Mi           
user-service-6b4c66cd8b-xdvck     3m           232Mi           
user-service-6b4c66cd8b-zwfjs     2m           259Mi           
boris@boris-Nitro-AN515-58:~$ 
```
