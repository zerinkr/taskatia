#!/bin/bash

set -e

echo "Deploying AKS Observability Stack..."

# Initialize Terraform
cd terraform
terraform init
terraform apply -auto-approve

# Get kubeconfig
az aks get-credentials --resource-group $(terraform output -raw resource_group_name) --name $(terraform output -raw cluster_name)

# Apply Kubernetes manifests
cd ../kubernetes

# Create namespaces
kubectl apply -f namespaces/

# Deploy monitoring stack
kubectl apply -f monitoring/

# Deploy logging stack
kubectl apply -f logging/

# Deploy tracing stack
kubectl apply -f tracing/

# Deploy microservice application
kubectl apply -f microsim/

# Deploy ingress controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

echo "Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pods --all --all-namespaces --timeout=300s

echo "Deployment complete!"
echo "Observability endpoints:"
echo "- Grafana: http://grafana.example.com"
echo "- Prometheus: http://prometheus.example.com"
echo "- Jaeger: http://jaeger.example.com"
echo "- Application: http://microsim.example.com"