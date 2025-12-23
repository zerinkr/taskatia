terraform {
  required_version = ">= 1.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    azapi = {
      source  = "Azure/azapi"
    }
  }
  backend "azurerm" {
    # Configure backend in CI/CD
  }
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "aks" {
  name     = "${var.prefix}-aks-rg"
  location = var.location
  
  tags = {
    environment = var.environment
    managed-by  = "terraform"
  }
}

# AKS Cluster - Using minimal configuration for cost
resource "azurerm_kubernetes_cluster" "main" {
  name                = "${var.prefix}-aks-cluster"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  dns_prefix          = "${var.prefix}-aks"
  kubernetes_version  = var.kubernetes_version
  
  # System node pool for critical services
  default_node_pool {
    name                = "system"
    node_count          = 1
    vm_size             = "Standard_B2s"  # Cheapest for dev
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = false
    os_disk_size_gb     = 30
    type                = "VirtualMachineScaleSets"
  }
  
  # User node pool for applications
  node_pool {
    name                = "user"
    node_count          = 2
    vm_size             = "Standard_B2s"
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = false
    os_disk_size_gb     = 30
    mode                = "User"
  }
  
  identity {
    type = "SystemAssigned"
  }
  
  network_profile {
    network_plugin = "kubenet"
    service_cidr   = "10.0.1.0/24"
    dns_service_ip = "10.0.1.10"
  }
  
  tags = {
    environment = var.environment
  }
}

# Network Configuration
resource "azurerm_virtual_network" "aks" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.aks.location
  resource_group_name = azurerm_resource_group.aks.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "aks" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.aks.name
  virtual_network_name = azurerm_virtual_network.aks.name
  address_prefixes     = ["10.0.0.0/22"]
}

# Container Registry for images
resource "azurerm_container_registry" "acr" {
  name                = "${replace(var.prefix, "-", "")}acr"
  resource_group_name = azurerm_resource_group.aks.name
  location            = azurerm_resource_group.aks.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Grant AKS pull permissions from ACR
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}