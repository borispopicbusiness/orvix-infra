# Interesting commands and the Calico ip pool migration

## The Calico FelixConfiguration resource

This command:

```bash
kubectl get felixconfiguration default -o yaml
```
retrieves the Calico **FelixConfiguration** resource named **default** and prints the complete resource as YAML.
A possible output might be:
```yaml
apiVersion: projectcalico.org/v3
kind: FelixConfiguration
metadata:
  name: default
spec:
  bpfEnabled: false
  logSeverityScreen: Info
  iptablesBackend: Auto
```
A couple of interesting variation of the command:
```bash
kubectl get felixconfiguration default -o yaml | less
```
The output i get looks like this:
```yaml
apiVersion: crd.projectcalico.org/v1
kind: FelixConfiguration
metadata:
  annotations:
    projectcalico.org/metadata: '{"creationTimestamp":"2025-10-01T06:21:53Z"}'
  creationTimestamp: "2025-10-01T06:21:53Z"
  generation: 1
  name: default
  resourceVersion: "1025"
  uid: 2161e3b1-c255-46d6-8022-fd304acd909b
spec:
  bpfConnectTimeLoadBalancing: TCP
  bpfHostNetworkedNATWithoutCTLB: Enabled
  bpfLogLevel: ""
  floatingIPs: Disabled
  logSeverityScreen: Info
  reportingInterval: 0s
```
Another useful variation is with **jsonpath**:
```bash
kubectl get felixconfiguration default -o jsonpath='{.spec}'
```
The the output of the command when using the jsonpath expression is
```bash
boris@boris-Nitro-AN515-58:~$ kubectl get felixconfiguration default -o jsonpath='{.spec}'
{"bpfConnectTimeLoadBalancing":"TCP","bpfHostNetworkedNATWithoutCTLB":"Enabled","bpfLogLevel":"","floatingIPs":"Disabled","logSeverityScreen":"Info","reportingInterval":"0s"}boris@boris-Nitro-AN515-58:~$ 
```

For more information about The FelixConfiguration resource see [this article](https://docs.tigera.io/calico/latest/reference/resources/felixconfig).

## The Calico IPPool resource

This command can be used when Calico is installed. It retrieves **the Calico IPPool resource** and displays it as YAML.
```bash
kubectl get ippool -o yaml
```
For example, I have the followibg ip pool defined in my homelab cluster:
```yaml
apiVersion: v1
items:
- apiVersion: crd.projectcalico.org/v1
  kind: IPPool
  metadata:
    annotations:
      kubectl.kubernetes.io/last-applied-configuration: |
        {"apiVersion":"crd.projectcalico.org/v1","kind":"IPPool","metadata":{"annotations":{},"name":"default-ipv4-ippool-new"},"spec":{"allowedUses":["Workload","Tunnel"],"blockSize":26,"cidr":"10.244.0.0/16","ipipMode":"Always","natOutgoing":true,"nodeSelector":"all()","vxlanMode":"Never"}}
    creationTimestamp: "2026-08-04T14:05:16Z"
    generation: 1
    name: default-ipv4-ippool-new
    resourceVersion: "1208071"
    uid: c5291369-a6cb-4c8b-a111-fa9570279936
  spec:
    allowedUses:
    - Workload
    - Tunnel
    blockSize: 26
    cidr: 10.244.0.0/16
    ipipMode: Always
    natOutgoing: true
    nodeSelector: all()
    vxlanMode: Never
kind: List
metadata:
  resourceVersion: ""
```
There are a couple of interesting parts that I would like to point out:

- **cidr: 10.244.0.0/16** This represents the ip pool that is available to Calico
- **ipipMode: Always** This means that Calico uses IP-in-IP encapsulation for traffic between nodes
- **natOutgoing: true** This means that Calico performs NAT for network packets sent by a pod to a destination outside the cidr.
- **nodeSelector: all()** This means that the ip pool can be used by any node inside the cluster.
- **blockSize: 26** Calico does not normally assign the entire **/16** to a node. It divides the pool into smaller allocation blocks.

## Interesting commands at the Worker-Node Leve

These commands are useful or debugging Kubernetes/Calico networking and traffic flow.
```bash
sudo iptables -t nat -L cali-nat-outgoing -n -v
sudo tcpdump -i eth0 host 192.168.1.50
sudo tcpdump -ni any port 8080
```
The iptables command helps you inspect the Calico NAT chain
- **-t** operate on the **NAT** table
- **-L** this switch lists rules
- **cali-nat-outgoing** the name of the chain
- **-n** don't resolve IP addresses/ports to names
- **-v** show verbose information, including packet and byte counters

The **cali-nat-outgoing** chain is created by calico for handling outgoing traffic that may need NAT.

The ouptut looks like this:
```bash
ubuntu@k8s-wn1:~$ sudo iptables -t nat -L cali-nat-outgoing -n -v
Chain cali-nat-outgoing (1 references)
 pkts bytes target     prot opt in     out     source               destination         
    8   525 MASQUERADE  0    --  *      *       0.0.0.0/0            0.0.0.0/0            /* cali:flqWnvo8yq4ULQLa */ match-set cali40masq-ipam-pools src ! match-set cali40all-ipam-pools dst random-fully
ubuntu@k8s-wn1:~$ 
```

The **pkts** and **bytes** columns are particularly useful. They tell us whether traffic has actually matched the rule.

This command captures packets on the **eth0** interface where either the source or destination is **192.16.1.50**
```bash
sudo tcpdump -i eth0 host 192.168.1.50
```

## Useful commands

Find the pod's ip:
```bash
kubectl get pods -A -o wide
```

Run **ping** from inside the pod"
```bash
kubectl exec -it gateway-584c4dbc99-jcxfl -- ping www.google.com
```

The status of **the Uncomplicated Firewall**: (usually checked on worker nodes)
```bash
sudo ufw status
```

## Useful TCP connectivity and HTTP communication commands.

```bash
curl -v http://192.168.1.10:8080
nc -vz 192.168.1.10 8080
wget -O- http://192.168.1.10:8080
```
It is important to note that:
```bash
nc -vz 192.168.1.10 8080
```
checks only TCP connectivity.


```bash
nc -lvnp 8080
nc -lvnp 8080 -s 0.0.0.0
sudo tcpdump -ni eth0 host 192.168.1.10 and port 8080
```

On the worker node:

```bash
sudo ipset list cali40all-ipam-pools
```

Create a new Calico ip pool:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: crd.projectcalico.org/v1
kind: IPPool
metadata:
  name: default-ipv4-ippool-new
spec:
  cidr: 10.244.0.0/16
  blockSize: 26
  ipipMode: Always
  vxlanMode: Never
  natOutgoing: true
  nodeSelector: all()
  allowedUses:
  - Workload
  - Tunnel
EOF
```

disable the old pool:

```bash
kubectl patch ippool default-ipv4-ippool \
  --type=merge \
  -p '{"spec":{"disabled":true}}'
```

A way you can restart your pod:

```bash
kubectl delete pod -n dev gateway-c95c655b4-58v8d
```

```bash
kubectl get pods -A
kubectl get pods -A -o wide
kubectl get svc -A
kubectl get ingress -A
kubectl get statefulset -A
kubectl get deploy -A
kubectl get cm -A -o yaml | grep 192.168
kubectl get secret -A -o yaml | grep 192.168
kubectl get statefulset -n dev
kubectl get pvc -n dev
kubectl get nodes -o wide
```

```bash
kubectl get all -A -o yaml > cluster-backup.yaml
```

```bash
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra$ grep -R "192.168" .
./helm/gateway/values-dev.yaml: - ip: "192.168.1.242" ./helm/gateway/values-dev.yaml: downstream.uri: "http://192.168.1.10:8080"
./environments/dev/keycloak/README.md:gateway traefik gateway.dev.k8s-svc.homelab 192.168.1.242 80 15h
./environments/dev/keycloak/README.md:keycloak-dev-keycloakx traefik keycloak-dev.keycloak.example.com 192.168.1.242 80 110m
./environments/dev/keycloak/README.md: the cluster IP 192.168.1.242. ./environments/misc/metallb/metallb-values.yaml: - 192.168.1.242-192.168.1.254 # choose free LAN IPs boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra7$
```

```bash
kubectl cluster-info dump | grep service-cluster-ip-range
ps aux | grep kube-apiserver | grep service-cluster-ip-range
```

```bash
kubectl get ippool -o yaml > calico-ippool-backup.yaml

kubectl get all -A -o yaml > cluster-resources-backup.yaml

kubectl get pvc -A > pvc-backup.txt

kubectl get felixconfiguration default -o yaml

kubectl get bgpconfiguration default -o yaml
```

    Your Calico pod CIDR (192.168.0.0/16) overlaps with your physical LAN (192.168.1.0/24). This is why pod → notebook traffic is leaving with the pod IP instead of being masqueraded.

```bash
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra$ kubectl get felixconfiguration default -o yaml
apiVersion: crd.projectcalico.org/v1
kind: FelixConfiguration
metadata:
  annotations:
    projectcalico.org/metadata: '{"creationTimestamp":"2025-10-01T06:21:53Z"}'
  creationTimestamp: "2025-10-01T06:21:53Z"
  generation: 1
  name: default
  resourceVersion: "1025"
  uid: 2161e3b1-c255-46d6-8022-fd304acd909b
spec:
  bpfConnectTimeLoadBalancing: TCP
  bpfHostNetworkedNATWithoutCTLB: Enabled
  bpfLogLevel: ""
  floatingIPs: Disabled
  logSeverityScreen: Info
  reportingInterval: 0s
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra$ kubectl get bgpconfiguration default -o yaml
Error from server (NotFound): bgpconfigurations.crd.projectcalico.org "default" not found
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra$ 
```

```yaml
spec:
  floatingIPs: Disabled
  bpfConnectTimeLoadBalancing: TCP
  bpfHostNetworkedNATWithoutCTLB: Enabled
```

Nothing here affects the pod CIDR migration.

Important observations:

- No custom Felix settings that would complicate migration.
- No floating IPs.
- eBPF-related options exist, but your earlier iptables output shows you are still using the iptables dataplane for NAT.

```bash
kubectl get bgpconfiguration default -o yaml
```

```bash
boris@boris-Nitro-AN515-58:~$ kubectl get bgpconfiguration default -o yaml
Error from server (NotFound): bgpconfigurations.crd.projectcalico.org "default" not found
boris@boris-Nitro-AN515-58:~$ 
```

That means I do not have a Calico BGP configuration object.
Combined with your IPPool:

```yaml
ipipMode: Always
vxlanMode: Never
```

my networking mode is:

    Pod
     |
     | veth
     |
    Calico
     |
     | IP-in-IP tunnel
     |
    tunl0
     |
    Other node

Calico is using IPIP, not BGP routing.

```bash
kubectl get pods -n tigera-operator
kubectl get installation default -o yaml
```

```bash
boris@boris-Nitro-AN515-58:~$ kubectl get pods -n tigera-operator
No resources found in tigera-operator namespace.
boris@boris-Nitro-AN515-58:~$ kubectl get installation default -o yaml
error: the server doesn't have a resource type "installation"
boris@boris-Nitro-AN515-58:~$
```

```bash
kubectl -n kube-system get ds calico-node -o yaml | grep -A3 CALICO_IPV4POOL
```

```bash
boris@boris-Nitro-AN515-58:~$ kubectl -n kube-system get ds calico-node -o yaml | grep -A3 CALICO_IPV4POOL
      {
  "apiVersion": "apps/v1",
  "kind": "DaemonSet",
  "metadata": {
    "annotations": {},
    "labels": {
      "k8s-app": "calico-node"
    },
    "name": "calico-node",
    "namespace": "kube-system"
  },
  "spec": {
    "selector": {
      "matchLabels": {
        "k8s-app": "calico-node"
      }
    },
    "template": {
      "metadata": {
        "labels": {
          "k8s-app": "calico-node"
        }
      },
      "spec": {
        "containers": [
          {
            "env": [
              {
                "name": "DATASTORE_TYPE",
                "value": "kubernetes"
              },
              {
                "name": "WAIT_FOR_DATASTORE",
                "value": "true"
              },
              {
                "name": "NODENAME",
                "valueFrom": {
                  "fieldRef": {
                    "fieldPath": "spec.nodeName"
                  }
                }
              },
              {
                "name": "CALICO_NETWORKING_BACKEND",
                "valueFrom": {
                  "configMapKeyRef": {
                    "key": "calico_backend",
                    "name": "calico-config"
                  }
                }
              },
              {
                "name": "CLUSTER_TYPE",
                "value": "k8s,bgp"
              },
              {
                "name": "IP",
                "value": "autodetect"
              },
              {
                "name": "CALICO_IPV4POOL_IPIP",
                "value": "Always"
              },
              {
                "name": "CALICO_IPV4POOL_VXLAN",
                "value": "Never"
              },
              {
                "name": "CALICO_IPV6POOL_VXLAN",
                "value": "Never"
              },
              {
                "name": "FELIX_IPINIPMTU",
                "valueFrom": {
                  "configMapKeyRef": {
                    "key": "veth_mtu",
                    "name": "calico-config"
                  }
                }
              },
              {
                "name": "FELIX_VXLANMTU",
                "valueFrom": {
                  "configMapKeyRef": {
                    "key": "veth_mtu",
                    "name": "calico-config"
                  }
                }
              },
              {
                "name": "FELIX_WIREGUARDMTU",
                "valueFrom": {
                  "configMapKeyRef": {
                    "key": "veth_mtu",
                    "name": "calico-config"
                  }
                }
              },
              {
                "name": "CALICO_DISABLE_FILE_LOGGING",
                "value": "true"
              },
              {
                "name": "FELIX_DEFAULTENDPOINTTOHOSTACTION",
                "value": "ACCEPT"
              },
              {
                "name": "FELIX_IPV6SUPPORT",
                "value": "false"
              },
              {
                "name": "FELIX_HEALTHENABLED",
                "value": "true"
              }
            ],
            "envFrom": [
              {
                "configMapRef": {
                  "name": "kubernetes-services-endpoint",
                  "optional": true
                }
              }
            ],
            "image": "docker.io/calico/node:v3.28.0",
            "imagePullPolicy": "IfNotPresent",
            "lifecycle": {
              "preStop": {
                "exec": {
                  "command": [
                    "/bin/calico-node",
                    "-shutdown"
                  ]
                }
              }
            },
            "livenessProbe": {
              "exec": {
                "command": [
                  "/bin/calico-node",
                  "-felix-live",
                  "-bird-live"
                ]
              },
              "failureThreshold": 6,
              "initialDelaySeconds": 10,
              "periodSeconds": 10,
              "timeoutSeconds": 10
            },
            "name": "calico-node",
            "readinessProbe": {
              "exec": {
                "command": [
                  "/bin/calico-node",
                  "-felix-ready",
                  "-bird-ready"
                ]
              },
              "periodSeconds": 10,
              "timeoutSeconds": 10
            },
            "resources": {
              "requests": {
                "cpu": "250m"
              }
            },
            "securityContext": {
              "privileged": true
            },
            "volumeMounts": [
              {
                "mountPath": "/host/etc/cni/net.d",
                "name": "cni-net-dir",
                "readOnly": false
              },
              {
                "mountPath": "/lib/modules",
                "name": "lib-modules",
                "readOnly": true
              },
              {
                "mountPath": "/run/xtables.lock",
                "name": "xtables-lock",
                "readOnly": false
              },
              {
                "mountPath": "/var/run/calico",
                "name": "var-run-calico",
                "readOnly": false
              },
              {
                "mountPath": "/var/lib/calico",
                "name": "var-lib-calico",
                "readOnly": false
              },
              {
                "mountPath": "/var/run/nodeagent",
                "name": "policysync"
              },
              {
                "mountPath": "/sys/fs/bpf",
                "name": "bpffs"
              },
              {
                "mountPath": "/var/log/calico/cni",
                "name": "cni-log-dir",
                "readOnly": true
              }
            ]
          }
        ],
        "hostNetwork": true,
        "initContainers": [
          {
            "command": [
              "/opt/cni/bin/calico-ipam",
              "-upgrade"
            ],
            "env": [
              {
                "name": "KUBERNETES_NODE_NAME",
                "valueFrom": {
                  "fieldRef": {
                    "fieldPath": "spec.nodeName"
                  }
                }
              },
              {
                "name": "CALICO_NETWORKING_BACKEND",
                "valueFrom": {
                  "configMapKeyRef": {
                    "key": "calico_backend",
                    "name": "calico-config"
                  }
                }
              }
            ],
            "envFrom": [
              {
                "configMapRef": {
                  "name": "kubernetes-services-endpoint",
                  "optional": true
                }
              }
            ],
            "image": "docker.io/calico/cni:v3.28.0",
            "imagePullPolicy": "IfNotPresent",
            "name": "upgrade-ipam",
            "securityContext": {
              "privileged": true
            },
            "volumeMounts": [
              {
                "mountPath": "/var/lib/cni/networks",
                "name": "host-local-net-dir"
              },
              {
                "mountPath": "/host/opt/cni/bin",
                "name": "cni-bin-dir"
              }
            ]
          },
          {
            "command": [
              "/opt/cni/bin/install"
            ],
            "env": [
              {
                "name": "CNI_CONF_NAME",
                "value": "10-calico.conflist"
              },
              {
                "name": "CNI_NETWORK_CONFIG",
                "valueFrom": {
                  "configMapKeyRef": {
                    "key": "cni_network_config",
                    "name": "calico-config"
                  }
                }
              },
              {
                "name": "KUBERNETES_NODE_NAME",
                "valueFrom": {
                  "fieldRef": {
                    "fieldPath": "spec.nodeName"
                  }
                }
              },
              {
                "name": "CNI_MTU",
                "valueFrom": {
                  "configMapKeyRef": {
                    "key": "veth_mtu",
                    "name": "calico-config"
                  }
                }
              },
              {
                "name": "SLEEP",
                "value": "false"
              }
            ],
            "envFrom": [
              {
                "configMapRef": {
                  "name": "kubernetes-services-endpoint",
                  "optional": true
                }
              }
            ],
            "image": "docker.io/calico/cni:v3.28.0",
            "imagePullPolicy": "IfNotPresent",
            "name": "install-cni",
            "securityContext": {
              "privileged": true
            },
            "volumeMounts": [
              {
                "mountPath": "/host/opt/cni/bin",
                "name": "cni-bin-dir"
              },
              {
                "mountPath": "/host/etc/cni/net.d",
                "name": "cni-net-dir"
              }
            ]
          },
          {
            "command": [
              "calico-node",
              "-init",
              "-best-effort"
            ],
            "image": "docker.io/calico/node:v3.28.0",
            "imagePullPolicy": "IfNotPresent",
            "name": "mount-bpffs",
            "securityContext": {
              "privileged": true
            },
            "volumeMounts": [
              {
                "mountPath": "/sys/fs",
                "mountPropagation": "Bidirectional",
                "name": "sys-fs"
              },
              {
                "mountPath": "/var/run/calico",
                "mountPropagation": "Bidirectional",
                "name": "var-run-calico"
              },
              {
                "mountPath": "/nodeproc",
                "name": "nodeproc",
                "readOnly": true
              }
            ]
          }
        ],
        "nodeSelector": {
          "kubernetes.io/os": "linux"
        },
        "priorityClassName": "system-node-critical",
        "serviceAccountName": "calico-node",
        "terminationGracePeriodSeconds": 0,
        "tolerations": [
          {
            "effect": "NoSchedule",
            "operator": "Exists"
          },
          {
            "key": "CriticalAddonsOnly",
            "operator": "Exists"
          },
          {
            "effect": "NoExecute",
            "operator": "Exists"
          }
        ],
        "volumes": [
          {
            "hostPath": {
              "path": "/lib/modules"
            },
            "name": "lib-modules"
          },
          {
            "hostPath": {
              "path": "/var/run/calico"
            },
            "name": "var-run-calico"
          },
          {
            "hostPath": {
              "path": "/var/lib/calico"
            },
            "name": "var-lib-calico"
          },
          {
            "hostPath": {
              "path": "/run/xtables.lock",
              "type": "FileOrCreate"
            },
            "name": "xtables-lock"
          },
          {
            "hostPath": {
              "path": "/sys/fs/",
              "type": "DirectoryOrCreate"
            },
            "name": "sys-fs"
          },
          {
            "hostPath": {
              "path": "/sys/fs/bpf",
              "type": "Directory"
            },
            "name": "bpffs"
          },
          {
            "hostPath": {
              "path": "/proc"
            },
            "name": "nodeproc"
          },
          {
            "hostPath": {
              "path": "/opt/cni/bin"
            },
            "name": "cni-bin-dir"
          },
          {
            "hostPath": {
              "path": "/etc/cni/net.d"
            },
            "name": "cni-net-dir"
          },
          {
            "hostPath": {
              "path": "/var/log/calico/cni"
            },
            "name": "cni-log-dir"
          },
          {
            "hostPath": {
              "path": "/var/lib/cni/networks"
            },
            "name": "host-local-net-dir"
          },
          {
            "hostPath": {
              "path": "/var/run/nodeagent",
              "type": "DirectoryOrCreate"
            },
            "name": "policysync"
          }
        ]
      }
    },
    "updateStrategy": {
      "rollingUpdate": {
        "maxUnavailable": 1
      },
      "type": "RollingUpdate"
    }
  }
}
  creationTimestamp: "2025-10-01T06:21:26Z"
  generation: 2
  labels:
--
        - name: CALICO_IPV4POOL_IPIP
          value: Always
        - name: CALICO_IPV4POOL_VXLAN
          value: Never
        - name: CALICO_IPV6POOL_VXLAN
          value: Never
boris@boris-Nitro-AN515-58:~$
```

I used Calico manifest installation, which is true.

```bash
bgpconfigurations.crd.projectcalico.org "default" not found
```

This does not mean BGP is not enabled.

The DaemonSet says:

    CLUSTER_TYPE=k8s,bgp

So Calico was installed with BGP support enabled internally.

However, k8s says:

    ipipMode: Always

in the IPPool, which means pod-to-pod traffic between nodes goes through IPIP tunnels (tunl0).

Your Calico configuration is controlled by these objects

```bash
kubectl get ippool
kubectl get felixconfiguration
kubectl get configmap -n kube-system calico-config
kubectl get ds -n kube-system calico-node
```

The pod CIDR comes from:

```bash
kubectl get ippool default-ipv4-ippool -o yaml
```

```yaml
cidr: 192.168.0.0/16
natOutgoing: true
ipipMode: Always
```

## Migration strategy for your exact installation

### 1. Create a backup

Create a backup:

```bash
kubectl get ippool -o yaml > ippool-backup.yaml
kubectl get felixconfiguration -o yaml > felix-backup.yaml
kubectl get ds -n kube-system calico-node -o yaml > calico-node-backup.yaml
```

### 2. Create a new ip pool

Create a new yaml file, name it new-ippool.yaml
```yaml
apiVersion: crd.projectcalico.org/v1
kind: IPPool
metadata:
  name: default-ipv4-ippool-new
spec:
  cidr: 10.244.0.0/16
  blockSize: 26
  ipipMode: Always
  vxlanMode: Never
  natOutgoing: true
  nodeSelector: all()
  allowedUses:
  - Workload
  - Tunnel
```

Apply it:
```bash
kubectl apply -f new-ippool.yaml
```

### 3. Disable the old pool

```bash
kubectl patch ippool default-ipv4-ippool \
  --type=merge \
  -p '{"spec":{"disabled":true}}'
```

### 4. The recreation procedure

```bash
kubectl rollout restart deployment -n traefik
kubectl rollout restart deployment -n metallb-system
kubectl rollout restart deployment -n sealed-secrets
kubectl rollout restart deployment -n dev
```

```bash
kubectl exec -n kube-system ds/calico-node -- birdcl show protocols
```

```bash
boris@boris-Nitro-AN515-58:~$ kubectl exec -n kube-system ds/calico-node -- birdcl show protocols
Defaulted container "calico-node" out of: calico-node, upgrade-ipam (init), install-cni (init), mount-bpffs (init)
BIRD v0.3.3+birdv1.6.8 ready.
name     proto    table    state  since       info
static1  Static   master   up     07:18:02    
kernel1  Kernel   master   up     07:18:02    
device1  Device   master   up     07:18:02    
direct1  Direct   master   up     07:18:02    
Mesh_192_168_1_241 BGP      master   up     07:20:58    Established   
Mesh_192_168_1_215 BGP      master   up     07:20:30    Established   
Mesh_192_168_1_203 BGP      master   up     07:18:24    Established   
boris@boris-Nitro-AN515-58:~$
```

```bash
kubectl rollout restart deployment -n kube-system coredns
kubectl rollout restart deployment -n kube-system calico-kube-controllers
kubectl rollout restart deployment -n local-path-storage local-path-provisioner
```