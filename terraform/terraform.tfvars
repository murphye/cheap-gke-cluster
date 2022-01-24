project_id  = "PROJECT_ID"

# Pick a region with low spot VM prices. us-west4 is currently the cheapest.
# Not all regions will work, some don't support STANDARD network tier.
# https://cloud.google.com/compute/vm-instance-pricing
region           = "us-west4"

zone             = "us-west4-a"
gke_cluster_name = "my-cluster"
num_nodes        = 3
machine_type     = "e2-standard-2"
disk_size        = 20
network_name     = "my-network"
ip_address_name  = "my-static-ip"
ssl_cert_name    = "my-ssl-cert"
ssl_cert_crt     = "certs/self-signed.crt"
ssl_cert_key     = "certs/self-signed.key"
# Change to true to enable HTTPS and HTTP redirect for the load balancer
https            = false