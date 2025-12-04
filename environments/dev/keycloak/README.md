# Keycloak (The development environment)

## Basic steps

These are the instructions we must to follow:

- Add the official Keycloak helm repo: helm repo add codecentric https://codecentric.github.io/helm-charts

```bash
helm repo add codecentric https://codecentric.github.io/helm-charts
````

- install Codecentric's official keycloak helm chart:
```bash
helm install keycloak codecentric/keycloakx
```

- Create values-dev.yaml to customize the fields and env variables

```yaml
replicas: 1

keycloak:
  username: admin
  password: admin

  database:
    vendor: h2
    host: ""
    database: ""
    username: ""
    password: ""

extraEnv: |
  - name: KEYCLOAK_ADMIN
    value: admin
  - name: KEYCLOAK_ADMIN_PASSWORD
    value: admin
  - name: KC_DB
    value: h2
  - name: KC_DB_URL_HOST
    value: ""
  - name: KC_DB_URL_DATABASE
    value: ""
  - name: KC_DB_USERNAME
    value: ""
  - name: KC_DB_PASSWORD
    value: ""
  - name: KC_CACHE
    value: ispn
  - name: KC_HTTP_RELATIVE_PATH
    value: /auth
```

- After we prepare the custom values yaml we can deploy the keycloak

```bash
helm install keycloak-dev cpdecentric/keycloakx -n dev -f values-dev.yaml
```

## The resources and limits concerns

For the remote development environment/namespace `dev` these two resources configurations are circulating for now:

```yaml
resources:
  limits:
    cpu: 1
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
```

```yaml
resources:
  limits:
    cpu: 1
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 1Gi
```

Should I be conservative or more generous with regard to the requested resources and limits?
