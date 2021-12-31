variable "project_id" {
  description = "The project ID to host the cluster in"
}

variable "region" {
  description = "The region to host the cluster in"
}

variable "zone" {
  description = "The zone to host the cluster in (required if is a zonal cluster)"
}

variable "gke_cluster_name" {
  description = "The zone to host the cluster in (required if is a zonal cluster)"
}


resource "google_compute_network" "default" {
  name                    = "my-network"
  auto_create_subnetworks = "false"
  project = var.project_id
  routing_mode = "REGIONAL"
}

resource "google_compute_subnetwork" "proxy" {
  provider = google-beta
  name          = "proxy-only-subnet"
  ip_cidr_range = "11.129.0.0/23"
  project       = google_compute_network.default.project
  region        = var.region
  network       = google_compute_network.default.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

# Subnet
resource "google_compute_subnetwork" "default" {
  name          = "${var.gke_cluster_name}-subnet"
  project       = google_compute_network.default.project
  region        = var.region
  network       = google_compute_network.default.name
  ip_cidr_range = "10.0.0.0/24"
}

resource "google_compute_router" "router" {
  name    = "nat-router"
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region
  network = google_compute_network.default.id
}

resource "google_compute_router_nat" "nat" {
  name                               = "my-router-nat"
  router                             = google_compute_router.router.name
  region                             = google_compute_router.router.region
  project                            = google_compute_router.router.project
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"
}

resource "google_container_cluster" "default" {
  provider = google-beta
  project = var.project_id
  name     = var.gke_cluster_name
  location = var.zone
  initial_node_count = 3
  networking_mode = "VPC_NATIVE"
  network    = google_compute_network.default.name
  subnetwork = google_compute_subnetwork.default.name
  logging_service = "none"

  node_config {
    spot = true
    machine_type = "e2-standard-2"
    disk_size_gb = 20
    tags = ["${var.gke_cluster_name}"]
  }
  
  addons_config {
    http_load_balancing {
      disabled = true
    }
  }

  private_cluster_config {
    enable_private_nodes = true
    enable_private_endpoint = false
    master_ipv4_cidr_block = "172.16.0.16/28"
  }

  ip_allocation_policy {
    cluster_ipv4_cidr_block = "5.0.0.0/16"
    services_ipv4_cidr_block = "5.1.0.0/16"
  }

  default_snat_status {
    disabled = true
  }

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block = "0.0.0.0/0"
      display_name = "World"
    }
  }
}

resource "null_resource" "local_k8s_context" {
  depends_on = [google_container_cluster.default]
  provisioner "local-exec" {
    command = "gcloud container clusters get-credentials ${var.gke_cluster_name} --project=${var.project_id} --zone=${var.zone}"
  }
}

resource "google_compute_forwarding_rule" "primary" {
  provider = google-beta
  depends_on = [google_compute_subnetwork.proxy]
  name   = "l7-xlb-forwarding-rule-http"
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.default.id
  network               = google_compute_network.default.id
  ip_address            = google_compute_address.default.id
  network_tier          = "STANDARD"
}

resource "google_compute_region_target_http_proxy" "default" {
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region
  name    = "l7-xlb-proxy-http"
  url_map = google_compute_region_url_map.default.id
}

resource "google_compute_region_url_map" "default" {
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region
  name            = "regional-l7-xlb-map-http"
  default_service = google_compute_region_backend_service.default.id
}

resource "google_compute_network_endpoint_group" "neg" {
  name         = "istio-ingressgateway"
  network      = google_compute_network.default.id
  subnetwork   = google_compute_subnetwork.default.id
  zone         = var.zone
  project      = var.project_id
}

resource "google_compute_region_backend_service" "default" {
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region

  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group = google_compute_network_endpoint_group.neg.self_link
    capacity_scaler = 1
    balancing_mode = "RATE"
    max_rate_per_endpoint = 3500
  }

  name        = "l7-xlb-backend-service-http"
  protocol    = "HTTP"
  timeout_sec = 10

  health_checks = [google_compute_region_health_check.default.id]
}

resource "google_compute_region_health_check" "default" {
  depends_on = [google_compute_firewall.default]
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region
  name   = "l7-xlb-basic-check-http"
  http_health_check {
    port_specification = "USE_SERVING_PORT"
    request_path = "/productpage"
  }
}

resource "google_compute_address" "default" {
  name = "my-static-ip"
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region
  network_tier = "STANDARD"
}

resource "google_compute_firewall" "default" {
  name = "fw-allow-health-check-and-proxy"
  network = google_compute_network.default.id
  project = google_compute_network.default.project
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "11.129.0.0/23"]
  allow {
    protocol = "tcp"
  }
  target_tags = ["${var.gke_cluster_name}"]
  direction = "INGRESS"
}