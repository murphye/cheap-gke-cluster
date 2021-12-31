# This will construct a VPC-native, private GKE cluster. For effective routing from the Regional External HTTP Load Balancer,
# having the VPC-native cluster is needed to make Gloo Edge's Envoy gateway-proxy pods routable via a standalone NEG.
# See links in the comments below for specifics. This page is a good place to understand the overall solution: 
# https://cloud.google.com/kubernetes-engine/docs/how-to/standalone-neg

resource "google_compute_subnetwork" "default" {
  name          = "${var.gke_cluster_name}-subnet"
  project       = google_compute_network.default.project
  region        = var.region
  network       = google_compute_network.default.name
  ip_cidr_range = "10.0.0.0/24"
}

resource "google_container_cluster" "default" {
  provider = google-beta
  project  = var.project_id
  name     = var.gke_cluster_name
  location = var.zone
  initial_node_count = var.num_nodes
  # More info on the VPC native cluster: https://cloud.google.com/kubernetes-engine/docs/how-to/standalone-neg#create_a-native_cluster
  networking_mode = "VPC_NATIVE"
  network    = google_compute_network.default.name
  subnetwork = google_compute_subnetwork.default.name
  # Disable the Google Cloud Logging service because you may overrun the Logging free tier allocation, and it may be expensive
  logging_service = "none"

  node_config {
    # More info on Spot VMs with GKE https://cloud.google.com/kubernetes-engine/docs/how-to/spot-vms#create_a_cluster_with_enabled
    spot = true
    machine_type = var.machine_type
    disk_size_gb = var.disk_size
    tags = ["${var.gke_cluster_name}"]
  }
  
  addons_config {
    http_load_balancing {
      # This needs to be enabled for the NEG to be automatically created for the ingress gateway svc
      disabled = false
    }
  }

  private_cluster_config {
    # Need to use private nodes for VPC-native GKE clusters
    enable_private_nodes = true
    # Allow private cluster Master to be accessible outside of the network
    enable_private_endpoint = false
    master_ipv4_cidr_block = "172.16.0.16/28"
  }

  ip_allocation_policy {
    cluster_ipv4_cidr_block = "5.0.0.0/16"
    services_ipv4_cidr_block = "5.1.0.0/16"
  }

  default_snat_status {
    # More infor on why sNAT needs to be disabled: https://cloud.google.com/kubernetes-engine/docs/how-to/alias-ips#enable_pupis
    # This applies to VPC-native GKE clusters
    disabled = true
  }

  master_authorized_networks_config {
    cidr_blocks {
      # Because this is a private cluster, need to open access to the Master nodes in order to connect with kubectl
      cidr_block = "0.0.0.0/0"
      display_name = "World"
    }
  }
}

resource "time_sleep" "wait_for_kube" {
  depends_on = [google_container_cluster.default]
  # GKE master endpoint will not be immediately accessible, resulting in error, waiting does the trick
  create_duration = "60s"
}

resource "null_resource" "local_k8s_context" {
  depends_on = [null_resource.local_k8s_context]
  provisioner "local-exec" {
    # Update your local gcloud and kubectl credentials for the newly created cluster
    command = "gcloud container clusters get-credentials ${var.gke_cluster_name} --project=${var.project_id} --zone=${var.zone}"
  }
}

