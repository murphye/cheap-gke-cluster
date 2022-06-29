resource "null_resource" "istio" {
  depends_on = [null_resource.local_k8s_context, google_compute_router_nat.nat]
  provisioner "local-exec" {
    # Update your local gcloud and kubectl credentials for the newly created cluster
    command = "./scripts/install-istio.sh"
  }
}
