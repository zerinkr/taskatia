
##Quick deploy.

git clone https://github.com/zerinkr/taskatia.git
cd taskatia

cd EKS/infrastructure/terraform
terraform init
terraform plan -var="cluster_name=my-aks-cluster" -var="resource_group=my-resource-group"
terraform apply


./infrastructure/scripts/deploy.sh




####Accessing Observability Tools

Note: Credentials and specific URLs have been shared via email.

Grafana Dashboard

URL: https://grafana.<domain>.com


Prometheus

URL: https://prometheus.<domain>.com
Features: Metrics collection and querying

Sample Application

URL: https://app.<domain>.com
Generates synthetic traces and metrics for testing