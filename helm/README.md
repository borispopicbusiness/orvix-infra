# Info

This directory contains the Helm charts for the microservices that belong to Orvix.
Each directory represents a single Helm chart. For example:

    gateway/ - represents the helm chart of gateway microservice
      Chart.yaml
      values-dev.yaml
      values-prod.yaml
      templates/
        deployment.yaml
        etc.

    users-service/ - represents the helm chart of users microservice
      Chart.yaml
      values-dev.yaml
      values-prod.yaml
      templates/
        deployment.yaml
        etc.