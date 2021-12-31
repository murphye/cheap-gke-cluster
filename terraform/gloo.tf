# Install Gloo Edge, an Envoy-based Kubernetes ingress and API gateway.
# Gloo provides HTTP ingress into the GKE cluster for this solution.
# Gloo's advanced API gateway features allow for easy resiliency.

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
  # This is the standard name format for GKE cluster kubectl contexts
  config_context = "gke_${var.project_id}_${var.zone}_${var.gke_cluster_name}"
}

resource "kubernetes_namespace" "gloo_system" {
  # Need to give a bit more time for the cluster to be reachable before the namespace can be created
  depends_on = [time_sleep.wait_for_kube]
  metadata {
    # gloo-system is the standard namespace for Gloo Edge
    name = "gloo-system"
  }
}

resource "helm_release" "gloo" {
  depends_on = [kubernetes_namespace.gloo_system]
  name       = "gloo-edge"
  # gloo-system is the standard namespace for Gloo Edge
  namespace  = "gloo-system"

  repository = "https://storage.googleapis.com/solo-public-helm"
  chart      = "gloo"
  
  set {
    # Because we are using a container native network, and the standalone NEG, only a ClusterIP is needed
    # More information can be found here: https://cloud.google.com/kubernetes-engine/docs/how-to/standalone-neg#create_a_service
    # Also, don't want to use LoadBalancer as that will automatically trigger creation of an unneeded GCP load balancer
    name  = "gatewayProxies.gatewayProxy.service.type"
    value = "ClusterIP"
    
  }

  set {
    # Because we are using only spot nodes, having at least 2 replicas is needed for resiliency
    name  = "gatewayProxies.gatewayProxy.kind.deployment.replicas"
    value = "2"
  }

  set {
    # Because we are using only spot nodes, need to have antiAffinity for resiliency
    name  = "gatewayProxies.gatewayProxy.antiAffinity"
    value = "true"
  }

  set {
    # This adds an extra annotation to the gateway-proxy Kubernetes service. With this annotation, a standalone NEG will 
    # automatically be generated making the gateway-proxy pods directly accessible in the network. 
    # More information can be found here: https://cloud.google.com/kubernetes-engine/docs/how-to/standalone-neg#create_a_service
    name  = "gatewayProxies.gatewayProxy.service.extraAnnotations.cloud\\.google\\.com/neg"
    value = <<EOT
    {"exposed_ports": {"80":{"name": "ingressgateway"}}}
    EOT
    # Helm is picky about string inputs, needed to escape . and put the JSON in a string block.
  }
}