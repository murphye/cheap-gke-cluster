resource "google_compute_forwarding_rule" "redirect" {
  depends_on = [google_compute_subnetwork.proxy]
  count      = var.https ? 1 : 0
  name       = "l7-xlb-forwarding-rule-http-redirect"
  project    = google_compute_subnetwork.default.project
  region     = google_compute_subnetwork.default.region
  ip_protocol           = "TCP"
  # Scheme required for a Regional External HTTP Load Balancer. This uses an external managed Envoy proxy
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_region_target_http_proxy.redirect.id
  network               = google_compute_network.default.id
  ip_address            = google_compute_address.default.id
  network_tier          = "STANDARD"
}

resource "google_compute_forwarding_rule" "https" {
  depends_on = [google_compute_subnetwork.proxy]
  count      = var.https ? 1 : 0
  name       = "l7-xlb-forwarding-rule-https"
  project    = google_compute_subnetwork.default.project
  region     = google_compute_subnetwork.default.region
  ip_protocol           = "TCP"
  # Scheme required for a Regional External HTTPS Load Balancer. This uses an external managed Envoy proxy
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_region_target_https_proxy.default.id
  network               = google_compute_network.default.id
  ip_address            = google_compute_address.default.id
  network_tier          = "STANDARD"
}

resource "google_compute_region_target_http_proxy" "redirect" {
  name    = "l7-xlb-proxy-http-redirect"
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region
  url_map = google_compute_region_url_map.redirect.id
}

resource "google_compute_region_url_map" "redirect" {
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region
  name    = "regional-l7-xlb-map-http-redirect"
  default_url_redirect {
    https_redirect = true
    strip_query    = false
  }
}

resource "google_compute_region_ssl_certificate" "default" { 
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region
  name        = var.ssl_cert_name
  description = "SSL certificate for l7-xlb-proxy-https"
  private_key = file(var.ssl_cert_key)
  certificate = file(var.ssl_cert_crt)
}

# https://registry.terraform.io/providers/hashicorp/google-beta/latest/docs/resources/compute_ssl_certificate#example-usage---ssl-certificate-target-https-proxies
resource "google_compute_region_target_https_proxy" "default" {
  project = google_compute_subnetwork.default.project
  region  = google_compute_subnetwork.default.region
  name    = "l7-xlb-proxy-https"
  url_map = google_compute_region_url_map.default.id
  ssl_certificates = [google_compute_region_ssl_certificate.default.id]
}