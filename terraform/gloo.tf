# Install Gloo Edge, an Envoy-based Kubernetes ingress and API gateway.
# Gloo provides HTTP ingress into the GKE cluster for this solution.
# Gloo's advanced API gateway features allow for easy resiliency.

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

resource "null_resource" "gloo" {
  depends_on = [helm_release.gloo_tf, null_resource.gloo_local]
}

resource "helm_release" "gloo_tf" {
  count = var.helm_local_exec ? 0 : 1
  depends_on = [null_resource.local_k8s_context]
  name       = "gloo-edge"
  # gloo-system is the standard namespace for Gloo Edge
  namespace  = "gloo-system"
  create_namespace = true

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

resource "null_resource" "gloo_local" {

  count = var.helm_local_exec ? 1 : 0
  depends_on = [null_resource.local_k8s_context]
  provisioner "local-exec" {
    # Update your local gcloud and kubectl credentials for the newly created cluster
    command = "./scripts/install-gloo.sh"
  }
}
