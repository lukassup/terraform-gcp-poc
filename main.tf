terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 3.88.0"
    }
    google-beta = {
      source  = "hashicorp/google"
      version = "~> 3.88.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.1.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
  }
}

/******************************************
  Provider configuration
 *****************************************/

variable "region" {
  default = "us-west1"
}

provider "google" {
  region = var.region
}

provider "google-beta" {
  region = var.region
}

/* Vars */

variable "organization_id" {}

variable "billing_account" {}

variable "folder_name" {}

variable "network_name" { default = "shared" }

resource "google_folder" "folder" {
  display_name = var.folder_name
  parent       = "organizations/${var.organization_id}"
}

module "vpc_host" {
  source  = "terraform-google-modules/project-factory/google"
  version = "~> 11.2.1"

  random_project_id              = true
  name                           = "shared-vpc-stg"
  org_id                         = var.organization_id
  folder_id                      = google_folder.folder.name
  billing_account                = var.billing_account
  enable_shared_vpc_host_project = true
}

/******************************************
  Network Creation
 *****************************************/
locals {
  subnet_01 = "${var.network_name}-subnet-01"
  subnet_02 = "${var.network_name}-subnet-02"
}

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 3.4.0"

  project_id                             = module.vpc_host.project_id
  network_name                           = var.network_name
  delete_default_internet_gateway_routes = true

  subnets = [
    {
      subnet_name   = local.subnet_01
      subnet_ip     = "10.10.10.0/24"
      subnet_region = var.region
    },
    {
      subnet_name           = local.subnet_02
      subnet_ip             = "10.10.20.0/24"
      subnet_region         = var.region
      subnet_private_access = true
      subnet_flow_logs      = true
    },
  ]

  secondary_ranges = {
    (local.subnet_01) = [
      {
        range_name    = "${local.subnet_01}-01"
        ip_cidr_range = "192.168.64.0/24"
      },
      {
        range_name    = "${local.subnet_01}-02"
        ip_cidr_range = "192.168.65.0/24"
      },
    ]

    (local.subnet_02) = [
      {
        range_name    = "${local.subnet_02}-01"
        ip_cidr_range = "192.168.66.0/24"
      },
    ]
  }
}

# /******************************************
#   Service Project Creation
#  *****************************************/
# module "service_project" {
#   source  = "terraform-google-modules/project-factory/google//modules/svpc_service_project"
#   version = "~> 11.2.1"
# 
#   name              = "terraform-demo-stg"
#   random_project_id = false
# 
#   org_id          = var.organization_id
#   folder_id       = google_folder.folder.name
#   billing_account = var.billing_account
# 
#   shared_vpc         = module.vpc_host.project_id
#   shared_vpc_subnets = module.vpc.subnets_self_links
# 
#   activate_apis = [
#     "compute.googleapis.com",
#     "container.googleapis.com",
#     "dataproc.googleapis.com",
#     "dataflow.googleapis.com",
#   ]
# 
#   disable_services_on_destroy = false
# }
