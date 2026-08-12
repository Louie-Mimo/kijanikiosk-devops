# KijaniKiosk Kubernetes Deployment

This directory contains the declarative Kubernetes manifests for the
KijaniKiosk Week 9 production-approaching deployment.

All application resources are deployed into the `kijani-project` namespace.

## Required Secret

The `kk-payments` Deployment requires a Kubernetes Secret named:

kk-payments-secrets

Required keys:

- DB_PASSWORD
- STRIPE_API_KEY
- JWT_SECRET

Secret values must not be committed to Git.

Obtain the correct values from the team before deploying the application.

For the local Week 9 lab environment, create the Secret manually with:

kubectl create secret generic kk-payments-secrets \
  --from-literal=DB_PASSWORD='<obtain-from-team>' \
  --from-literal=STRIPE_API_KEY='<obtain-from-team>' \
  --from-literal=JWT_SECRET='<obtain-from-team>' \
  -n kijani-project

The file `kk-payments-secrets.yaml.example` documents the required Secret
structure without containing actual credentials.

## Deployment

After the required Secret has been created, apply the manifests with:

kubectl apply -f k8s/
