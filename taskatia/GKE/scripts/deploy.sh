#!/bin/bash
# scripts/deploy.sh

# Initialize Terraform
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan

# Get cluster credentials
gcloud container clusters get-credentials $(terraform output -raw cluster_name) \
  --zone $(terraform output -raw zone)

# Create namespaces
kubectl apply -f kubernetes/namespaces/

# Install cert-manager for TLS
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml

# Deploy observability stack
kubectl apply -f kubernetes/observability/

# Deploy sample application
kubectl apply -f kubernetes/sample-app/

# Deploy networking
kubectl apply -f kubernetes/networking/

# Deploy security policies
kubectl apply -f kubernetes/security/