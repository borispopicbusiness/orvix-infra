# Miscellaneous

## Bitnami Sealed Secrets

### Why do we need Sealed Secrets

The repositories are publicly available; therefore, no credentials should be stored in plain text. Credentials sometimes
appear in both application code and infrastructure YAML files, so storing them unprotected would be insecure. To address
this, I decided to use Bitnami Sealed Secrets to safely store encrypted credentials in GitHub repositories while reducing
the effort required to manage them across microservices and other systems where credentials are needed.

### The architectural organization & installation

Bitnami Sealed Secrets is set up as cluster-scoped. I have three namespaces inside the cluster `dev`, `stage`, `prod`.
Actually there is a fourth namespace as well.

These are the installation instructions:

Add Bitnami's repository.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
```

Fetch the latest repository information

```bash
helm repo update
```

Create a dedicated namespace for Sealed Secrets

```bash
kubectl create namespace sealed-secrets
```

Install the Sealed Secrets controller inside the namespace. Do not forget to set **clusterWide** property to **true**.

```bash
helm install sealed-secrets bitnami/sealed-secrets --namespace sealed-secrets --set clusterWide=true
```

Verify that the controller is operating inside the dedicated namespace.

```bash
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra$ kubectl get pods -n sealed-secrets
NAME                             READY   STATUS    RESTARTS        AGE
sealed-secrets-c5b4f946c-9l66b   1/1     Running   1 (4m39s ago)   5m30s
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra$ 
```

Now, kubeseal cli

```bash
curl -LO "https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.33.1/kubeseal-0.33.1-linux-amd64.tar.gz"
tar -xvzf kubeseal-0.33.1-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

You may create your first sealed secret it.

```bash
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra$ kubectl create secret generic mysecret --from-literal=username=user --from-literal=password=1234! -n dev --dry-run=client -o yaml | kubeseal --controller-name=sealed-secrets --controller-namespace=sealed-secrets --format yaml > test-sealed-secrets.yaml
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra$ 
```

For testing purposes, let's apply our sealed secret to our k8s cluster.

```bash
kubectl apply -f test-sealed-secrets.yaml
kubectl get secrets -n dev
```

This is the output of the last command:

```bash
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra/environments/misc$ kubectl get secrets -n dev
NAME                            TYPE                 DATA   AGE
mysecret                        Opaque               2      17s
sh.helm.release.v1.gateway.v1   helm.sh/release.v1   1      14d
sh.helm.release.v1.gateway.v2   helm.sh/release.v1   1      6d9h
sh.helm.release.v1.gateway.v3   helm.sh/release.v1   1      6d9h
sh.helm.release.v1.gateway.v4   helm.sh/release.v1   1      6d9h
sh.helm.release.v1.gateway.v5   helm.sh/release.v1   1      6d6h
sh.helm.release.v1.gateway.v6   helm.sh/release.v1   1      5d4h
sh.helm.release.v1.gateway.v7   helm.sh/release.v1   1      5d3h
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra/environments/misc$
```

As you can see `mysecret` is in the namespace

```bash
kubectl describe secret mysecret -n dev
```

```bash
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra/environments/misc$ kubectl describe secret mysecret -n dev
Name:         mysecret
Namespace:    dev
Labels:       <none>
Annotations:  <none>

Type:  Opaque

Data
====
password:  5 bytes
username:  4 bytes
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra/environments/misc$ 
```

Lets see the real data stored in the sealed secret

```bash
kubectl get secret mysecret -n dev -o jsonpath='{.data.username}' | base64 --decode
kubectl get secret mysecret -n dev -o jsonpath='{.data.password}' | base64 --decode
```

The output is `user` and `1234!`. 

So, Bitnami Sealed Secrets is set up.