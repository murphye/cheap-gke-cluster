# This solution deploys a Regional External HTTP Load Balancer that routes traffic from the Internet to
# the ingress gateway for the GKE Cluster. The Regional External HTTP Load Balancer uses Envoy as a 
# managed proxy deployment. More information on the Regional External HTTP Load Balancer can be found here:
# https://cloud.google.com/load-balancing/docs/https#regional-connections

# Subnet reserved for Regional External HTTP Load Balancers that use a managed Envoy proxy.
# More information is available here: https://cloud.google.com/load-balancing/docs/https/proxy-only-subnets
resource "google_compute_subnetwork" "proxy" {
  depends_on = [google_compute_network.default]
  provider = google-beta
  name          = "proxy-only-subnet"
  # This CIDR doesn't conflict with GKE's subnet
  ip_cidr_range = "11.129.0.0/23"
  project       = google_compute_network.default.project
  region        = var.region
  network       = google_compute_network.default.id
  purpose       = "REGIONAL_MANAGED_PROXY"
  role          = "ACTIVE"
}

# https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_region_backend_service
resource "google_compute_region_backend_service" "default" {
  # This cannot be deployed until the ingress gateway is deployed and the standalone NEG is automatically created
  depends_on = [null_resource.gloo, null_resource.delete_ingressgateway]
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region
  name        = "l7-xlb-backend-service-http"
  protocol    = "HTTP"
  timeout_sec = 10

  # Scheme required for a Regional External HTTP Load Balancer. This uses an external managed Envoy proxy
  load_balancing_scheme = "EXTERNAL_MANAGED"
  health_checks = [google_compute_region_health_check.default.id]

  backend {
    # See the gloo.tf for more information on the ingressgateway standalone NEG that is automatically created
    group = "https://www.googleapis.com/compute/v1/projects/${var.project_id}/zones/${var.zone}/networkEndpointGroups/ingressgateway"
    capacity_scaler = 1
    balancing_mode = "RATE"
    # This is a reasonable max rate for an Envoy proxy
    max_rate_per_endpoint = 3500
  }

  circuit_breakers {
    max_retries = 10 # Default is 3
  }

  outlier_detection {
    consecutive_errors = 2 # Be aggressive about ejecting, the Gloo Edge gatway is likely no longer available 
    base_ejection_time {
      seconds = 30 # 30 is the default
    }
    interval {
      seconds = 1 # 10 is the default, be aggressive about detection of the Gloo Edge gateway being offline
    }
    max_ejection_percent = 50
  }
}

resource "null_resource" "delete_ingressgateway" {
  provisioner "local-exec" {
    when    = destroy
    # Delete ingressgateway on destroy
    command = "gcloud compute network-endpoint-groups delete ingressgateway --quiet"
  }
}

# https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_region_health_check
resource "google_compute_region_health_check" "default" {
  depends_on = [google_compute_firewall.default]
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region
  name   = "l7-xlb-basic-check-http"
  http_health_check {
    port_specification = "USE_SERVING_PORT"
    request_path = "/"
  }
  timeout_sec         = 1
  check_interval_sec  = 3
  healthy_threshold   = 1
  unhealthy_threshold = 1
}

resource "google_compute_address" "default" {
  name = var.ip_address_name
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region
  # Required to be STANDARD for use with REGIONAL_MANAGED_PROXY
  network_tier = "STANDARD"
}

resource "google_compute_firewall" "default" {
  name = "fw-allow-health-check-and-proxy"
  network = google_compute_network.default.id
  project = google_compute_network.default.project
  # Allow for ingress from the health checks and the managed Envoy proxy. For more information, see:
  # https://cloud.google.com/load-balancing/docs/https#target-proxies
  source_ranges = ["130.211.0.0/22", "35.191.0.0/16", "11.129.0.0/23"]
  allow {
    protocol = "tcp"
  }
  target_tags = ["${var.gke_cluster_name}"]
  direction = "INGRESS"
}
