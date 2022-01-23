# Install Gloo Edge, an Envoy-based Kubernetes ingress and API gateway.
# Gloo provides HTTP ingress into the GKE cluster for this solution.
# Gloo's advanced API gateway features allow for easy resiliency.

resource "null_resource" "gloo" {
  depends_on = [null_resource.local_k8s_context]
  provisioner "local-exec" {
    # Update your local gcloud and kubectl credentials for the newly created cluster
    command = "./scripts/install-gloo.sh"
  }
}
