# Keycloak (The development environment)

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