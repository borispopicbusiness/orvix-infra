# Keycloak (The development environment)

## Important note

This README.md suppose that the reader has already gone through [README.md](../misc/metallb/README.md) in [../misc/metallb](../misc/metallb)

## Basic steps

These are the instructions must be followed:

- Add the official Keycloak helm repo: codecentric https://codecentric.github.io/helm-charts

```bash
helm repo add codecentric https://codecentric.github.io/helm-charts
````

- install Codecentric's official keycloak helm chart:

```bash
helm install keycloak codecentric/keycloakx
```

- Create values-dev.yaml to customize the fields and env variables

- After preparing the custom values yaml, Keycloak can be deployed

```bash
helm install keycloak-dev codecentric/keycloakx -n dev -f values-dev.yaml
```
or

```bash
helm upgrade --install keycloak-dev codecentric/keycloakx -n dev -f ./environments/dev/keycloak/values-dev.yaml
```

## The resources and limits concerns

The previously raised resources-and-limits concerns turned out to be unnecessary because the inspection of the keycloak pod showed

```bash
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra$ kubectl describe pod gateway-68f66bbf88-rqb4p -n dev
```

that the already integrated minimum resources and limits satisfy my current needs

    Limits:
      cpu:     1
      memory:  1Gi
    Requests:
      cpu:        500m
      memory:     500Mi

So, I will leave this configuration unchanged in the deployment for now.

## Setting up the keycloak

Inside values-dev.yaml there is extraEnv property:

```yaml
extraEnv: |
  - name: KEYCLOAK_ADMIN
    valueFrom:
      secretKeyRef:
        name: keycloak-ss-dev
        key: KEYCLOAK_ADMIN
  - name: KEYCLOAK_ADMIN_PASSWORD
    valueFrom:
      secretKeyRef:
        name: keycloak-ss-dev
        key: KEYCLOAK_ADMIN_PASSWORD
  - name: KC_FEATURES
    value: preview
  - name: KC_HOSTNAME
    value: "keycloak-dev.keycloak.example.com"
  - name: KC_HOSTNAME_STRICT
    value: "true"
  - name: KC_PROXY
    value: "edge"
```

Here, I include the sealed secrets stored in the [keycloak-ss-dev-sealed.yaml](./keycloak-ss-dev-sealed.yaml) file.
As a matter of best practice I will not reveal the plain credentials and will keep them private. Anyone familiar with
the procedure, which is not complex, can (re)create their own sealed secret if needed.

&#x26A0;I believe this is optional, but I am leaving it in `extraEnv`; a deeper investigation will be conducted regarding it
```yaml
  - name: KC_HOSTNAME_STRICT
    value: "true"
```

I use H2 as the primary database for development purposes. Therefore, I have disabled it in the configuration file.

```yaml
postgresql:
  enabled: false
```

The configuration snippet down below is essential, it enables H2 and starts the Keycloak instance with H2 inside the container.

```yaml
command:
- "/opt/keycloak/bin/kc.sh"
- "start-dev"
```

We use only one replica for development purposes

```yaml
keycloak:
  replicas: 1
```

An ingress is configured inside the configuration file too.

```yaml
ingress:
  enabled: true
  className: traefik
  hosts:
    - host: keycloak-dev.keycloak.example.com
      paths:
        - path: /
          pathType: Prefix
```

## Post-installation diagnostics

One the set-up is completed, we should be able to see similar outputs:

```bash
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra$ kubectl get svc -n dev
NAME                              TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)                    AGE
gateway                           ClusterIP   10.107.166.250   <none>        8080/TCP                   15h
keycloak-dev-keycloakx-headless   ClusterIP   None             <none>        80/TCP                     110m
keycloak-dev-keycloakx-http       ClusterIP   10.108.48.171    <none>        9000/TCP,80/TCP,8443/TCP   110m
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra$ kubectl get ingress -n dev
NAME                     CLASS     HOSTS                               ADDRESS         PORTS   AGE
gateway                  traefik   gateway.dev.k8s-svc.homelab         192.168.1.242   80      15h
keycloak-dev-keycloakx   traefik   keycloak-dev.keycloak.example.com   192.168.1.242   80      110m
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra$ kubectl get pods -n dev
NAME                       READY   STATUS    RESTARTS       AGE
gateway-68f66bbf88-rqb4p   1/1     Running   4 (3h1m ago)   15h
keycloak-dev-keycloakx-0   1/1     Running   0              110m
boris@boris-Nitro-AN515-58:~/core-repos/orvix/orvix-infra$ 
```

- **Services** (`kubectl get svc -n dev`): The cluster provides a `ClusterIP` for the gateway and keycloak services.
  The gateway service exposes port 808, while Keycloak is accessible over multiple ports, 80, 9000, and 8443. A headless 
  service for Keycloak `keycloak-dev-keycloakx-headless` allows internal pod-to-pod communication.
- **Ingress** (`kubectl get ingress -n dev`): The `gateway` and Keycloak services are exposed externally through Traefik.
  You can access them at `gateway.dev.k8s-svc.homelab` and `keycloak-dev.keycloak.example.com` respectively, both mapped to
  the cluster IP `192.168.1.242`.

This confirms that the microservices and ingress routing are correctly deployed and the environment is ready for local
development and testing.

## Importing orvix-realm.jaml into Keycloak

In the [orvix-gateway](https://github.com/borispopicbusiness/orvix-gateway) repository there is a directory called `keycloak-export`.
Inside the directory you will find a json file called `orvix-realm.json`; it has to be imported into Keycloak. The import
procedure is very simple.

1. Log in to Keycloak
2. In the left navigation panel, click the **Manage realms** button
3. Click the blue button `Create realm` in the main working space, and a dialog titled `Create realm` will appear
4. In the same line as the label ***Resource file***, click ***Browse...***, locate the file, and upload it.
5. Then, click the ***Create*** button in the bottom-left corner of the dialog.

The system will successfully create a `orvix-realm`

## Testing inter-cluster communication between gateway and keycloak

The gateway has an endpoint that lets us fetch the available services inside the k8s cluster. This is one of the diagnostics
endpoints(e.g. the current implementation is very modest)

The shell snippet below shows the result of one carefully prepared curl meant to the endpoint. The curl I prepared is

```bash
curl -H "Host: gateway.dev.k8s-svc.homelab" \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJXNDZkQzZqcy1ob3VTX1NxT05ydlFKUWd2NXhTSFhaaUtjZFFScnRGU0FRIn0.eyJleHAiOjE3NjU0NjYwMjUsImlhdCI6MTc2NTQ0ODAyNSwianRpIjoib25ydHJvOjA2YTJlOTE2LTNiNmYtOWUyMS0yZTM1LTI1NWFjMTgxZTY0ZiIsImlzcyI6Imh0dHA6Ly9rZXljbG9hay1kZXYua2V5Y2xvYWsuZXhhbXBsZS5jb20vYXV0aC9yZWFsbXMvb3J2aXgtcmVhbG0iLCJhdWQiOiJhY2NvdW50Iiwic3ViIjoiOGRmNzMyNDEtNGE3OC00Y2FiLTk5ZDQtMTNhMWI1OGViMTFmIiwidHlwIjoiQmVhcmVyIiwiYXpwIjoib3J2aXgtZ2F0ZXdheS1kZXYtbG9jYWwiLCJzaWQiOiJjZGJhMDNmYy1hNzdjLTc0NDQtM2E2NC1jOTcxMzkwYzEyYTAiLCJhY3IiOiIxIiwiYWxsb3dlZC1vcmlnaW5zIjpbImh0dHA6Ly9sb2NhbGhvc3Q6ODA4MCJdLCJyZWFsbV9hY2Nlc3MiOnsicm9sZXMiOlsiZGVmYXVsdC1yb2xlcy1vcnZpeC1yZWFsbSIsIm9mZmxpbmVfYWNjZXNzIiwidW1hX2F1dGhvcml6YXRpb24iXX0sInJlc291cmNlX2FjY2VzcyI6eyJhY2NvdW50Ijp7InJvbGVzIjpbIm1hbmFnZS1hY2NvdW50IiwibWFuYWdlLWFjY291bnQtbGlua3MiLCJ2aWV3LXByb2ZpbGUiXX19LCJzY29wZSI6Im9wZW5pZCBlbWFpbCBwcm9maWxlIiwiZW1haWxfdmVyaWZpZWQiOmZhbHNlLCJuYW1lIjoidXNlci0gZGV2LWxvY2FsIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlci1kZXYtbG9jYWwiLCJnaXZlbl9uYW1lIjoidXNlci0iLCJmYW1pbHlfbmFtZSI6ImRldi1sb2NhbCIsImVtYWlsIjoidGVzdEB0ZXN0LmNvbSJ9.TV10n7p0GK-NO087ibsvy5m2FxOfU_RHRDJw9Y1EjfRAiRPU1BQO9Eu58qCFQamg_Hrfiq4LVTLUQV3G1waWhguGqp41DxpMtDPAP8NMSWFkdrQqxBxo4QcvW8ukcKFepG60pvezMmU7OuYpK-17JY4udbkhME3hpQwBq8JXoC8U-j8_yqesDX5_PUu_u1Sv5WY7HbIUPFq4k7iVel-0REzGMYYR5vxWtIbhKSyBp0NNLG5qz6RmtWxlOB5vp-7-caFjr0jjpGPQqKFrbmzkbuyqarAiJA2POXcP_38Q8CnlquLHyLhrps9MI1a4b596cSdS_Fk_yCLTQgGAuGmzHg" \
  http://keycloak-dev.keycloak.example.com/api/v1/diagnostics/cloud/services/all | \
  jq
```

&#x26A0;&#xFE0F;&#x26A0;&#xFE0F;&#x26A0;&#xFE0F; The access token in `-H "Authorization: Bearer ...` worked for me. Keep that in mind.


```bash
curl -H "Host: gateway.dev.k8s-svc.homelab" -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCIgOiAiSldUIiwia2lkIiA6ICJXNDZkQzZqcy1ob3VTX1NxT05ydlFKUWd2NXhTSFhaaUtjZFFScnRGU0FRIn0.eyJleHAiOjE3NjU0NjYwMjUsImlhdCI6MTc2NTQ0ODAyNSwianRpIjoib25ydHJvOjA2YTJlOTE2LTNiNmYtOWUyMS0yZTM1LTI1NWFjMTgxZTY0ZiIsImlzcyI6Imh0dHA6Ly9rZXljbG9hay1kZXYua2V5Y2xvYWsuZXhhbXBsZS5jb20vYXV0aC9yZWFsbXMvb3J2aXgtcmVhbG0iLCJhdWQiOiJhY2NvdW50Iiwic3ViIjoiOGRmNzMyNDEtNGE3OC00Y2FiLTk5ZDQtMTNhMWI1OGViMTFmIiwidHlwIjoiQmVhcmVyIiwiYXpwIjoib3J2aXgtZ2F0ZXdheS1kZXYtbG9jYWwiLCJzaWQiOiJjZGJhMDNmYy1hNzdjLTc0NDQtM2E2NC1jOTcxMzkwYzEyYTAiLCJhY3IiOiIxIiwiYWxsb3dlZC1vcmlnaW5zIjpbImh0dHA6Ly9sb2NhbGhvc3Q6ODA4MCJdLCJyZWFsbV9hY2Nlc3MiOnsicm9sZXMiOlsiZGVmYXVsdC1yb2xlcy1vcnZpeC1yZWFsbSIsIm9mZmxpbmVfYWNjZXNzIiwidW1hX2F1dGhvcml6YXRpb24iXX0sInJlc291cmNlX2FjY2VzcyI6eyJhY2NvdW50Ijp7InJvbGVzIjpbIm1hbmFnZS1hY2NvdW50IiwibWFuYWdlLWFjY291bnQtbGlua3MiLCJ2aWV3LXByb2ZpbGUiXX19LCJzY29wZSI6Im9wZW5pZCBlbWFpbCBwcm9maWxlIiwiZW1haWxfdmVyaWZpZWQiOmZhbHNlLCJuYW1lIjoidXNlci0gZGV2LWxvY2FsIiwicHJlZmVycmVkX3VzZXJuYW1lIjoidXNlci1kZXYtbG9jYWwiLCJnaXZlbl9uYW1lIjoidXNlci0iLCJmYW1pbHlfbmFtZSI6ImRldi1sb2NhbCIsImVtYWlsIjoidGVzdEB0ZXN0LmNvbSJ9.TV10n7p0GK-NO087ibsvy5m2FxOfU_RHRDJw9Y1EjfRAiRPU1BQO9Eu58qCFQamg_Hrfiq4LVTLUQV3G1waWhguGqp41DxpMtDPAP8NMSWFkdrQqxBxo4QcvW8ukcKFepG60pvezMmU7OuYpK-17JY4udbkhME3hpQwBq8JXoC8U-j8_yqesDX5_PUu_u1Sv5WY7HbIUPFq4k7iVel-0REzGMYYR5vxWtIbhKSyBp0NNLG5qz6RmtWxlOB5vp-7-caFjr0jjpGPQqKFrbmzkbuyqarAiJA2POXcP_38Q8CnlquLHyLhrps9MI1a4b596cSdS_Fk_yCLTQgGAuGmzHg" http://keycloak-dev.keycloak.example.com/api/v1/diagnostics/cloud/services/all | jq
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    75  100    75    0     0    104      0 --:--:-- --:--:-- --:--:--   104
[
  "gateway",
  "keycloak-dev-keycloakx-headless",
  "keycloak-dev-keycloakx-http"
]
```

So, we see the expected result; Ttree services are listed. Indeed as shown in the results of the diagnostics results, in 
particular for `kubectl get svc -n dev`