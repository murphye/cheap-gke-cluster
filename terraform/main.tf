

variable "project_id" {
  description = "The project ID to host the cluster in"
}

variable "region" {
  description = "The region to host the cluster in"
}

variable "zone" {
  description = "The zone to host the cluster in (required if is a zonal cluster)"
}

variable "network_name" {
  description = "The name of the network"
}

variable "gke_cluster_name" {
  description = "The name of the cluster"
}

variable "num_nodes" {
  description = "The number of cluster nodes"
}

variable "machine_type" {
  description = "The machine type of the cluster nodes"
}

variable "disk_size" {
  description = "The disk size of the cluster nodes"
}

variable "ip_address_name" {
  description = "The name of the static IP Address for the load balancer"
}

variable "ssl_cert_name" {
  description = "The name of the SSL certificate for the load balancer"
}

variable "https" {
  description = "Whether to set up the load balancer with HTTPS or not"
}

variable "ssl_cert_crt" {
  description = "Path to the SSL certificate .crt"
}

variable "ssl_cert_key" {
  description = "Path to the SSL certificate private .key"
}

resource "google_compute_network" "default" {
  name                    = var.network_name
  auto_create_subnetworks = "false"
  project = var.project_id
  # Everything in this solution is deployed regionally
  routing_mode = "REGIONAL"
}
