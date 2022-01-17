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

resource "google_compute_forwarding_rule" "primary" {
  depends_on = [google_compute_subnetwork.proxy]
  name       = "l7-xlb-forwarding-rule-http"
  project    = google_compute_subnetwork.default.project
  region     = google_compute_subnetwork.default.region
  ip_protocol           = "TCP"
  # Scheme required for a Regional External HTTP Load Balancer. This uses an external managed Envoy proxy
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.default.id
  network               = google_compute_network.default.id
  ip_address            = google_compute_address.default.id
  network_tier          = "STANDARD"
}

# https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_region_target_http_proxy
resource "google_compute_region_target_http_proxy" "default" {
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region
  name    = "l7-xlb-proxy-http"
  url_map = google_compute_region_url_map.default.id
}

# https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_region_url_map
resource "google_compute_region_url_map" "default" {
  depends_on = [google_compute_region_backend_service.default]
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region
  name    = "regional-l7-xlb-map-http"
  default_service = google_compute_region_backend_service.default.id

  # Pulled from example: https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_region_url_map#example-usage---region-url-map-l7-ilb-path
  # This is Envoy-specific configuration
  path_matcher {
    name = "allpaths"
    default_service = google_compute_region_backend_service.default.id
    path_rule {
      service = google_compute_region_backend_service.default.id
      paths   = ["/"]
      route_action {
        # Because the ingress gateways run on spot nodes, there might be connection draining issues or other connection issues
        # while the node/pod are shutting down. With the retry mechanism, the traffic should shift to the other instance of the
        # ingress gateway on the retries.
        retry_policy {
          num_retries = 3
          per_try_timeout {
            seconds = 1
          }
          retry_conditions = ["5xx", "deadline-exceeded"]
        }
      }
    }
  } 
}

resource "google_compute_region_backend_service" "default" {
  # This cannot be deployed until the ingress gateway is deployed and the standalone NEG is automatically created
  depends_on = [helm_release.gloo]
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
  check_interval_sec  = 1
  healthy_threshold   = 3
  unhealthy_threshold = 3
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
resource "null_resource" "decomission_ingressgateway" {
  provisioner "local-exec" {
    when = destroy
    # Delete ingressgateway on destroy
    command = "gcloud compute network-endpoint-groups delete ingressgateway --quiet"
  }
}
