resource "google_compute_forwarding_rule" "http" {
  depends_on = [google_compute_subnetwork.proxy]
  count      = var.https ? 0 : 1
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
          num_retries = 5
          per_try_timeout {
            seconds = 1
          }
          retry_conditions = ["5xx", "deadline-exceeded", "connect-failure"]
        }
      }
    }
  } 
}