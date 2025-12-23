# terraform/main.tf
provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_container_cluster" "primary" {
  name     = "devops-assignment-cluster"
  location = var.zone
  
  # Cost-optimized configuration
  remove_default_node_pool = true
  initial_node_count = 1
  
  # Security hardening
  enable_shielded_nodes = true
  enable_intranode_visibility = true
  datapath_provider = "ADVANCED_DATAPATH"
  
  # Maintenance window
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "spot-node-pool"
  cluster    = google_container_cluster.primary.name
  location   = var.zone
  
  # Spot instances for cost savings
  node_config {
    preemptible  = true
    machine_type = "e2-medium"
    disk_size_gb = 50
    
    # Security
    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
  
  # Autoscaling
  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }
}