cd terraform
terraform destroy -auto-approve

# Clean up GCP resources
gcloud projects delete $PROJECT_ID --quiet