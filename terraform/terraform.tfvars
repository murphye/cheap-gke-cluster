project_id  = "REPLACE_WITH_YOUR_PROJECT_ID"

# Pick a region with low spot VM prices. us-west4 is currently the cheapest. asia-east2 and southamerica-east1 are also cheap options.
# https://cloud.google.com/compute/vm-instance-pricing
#
# Not all GCP regions will work, as some don't support STANDARD network tier. Regions supporting STANDARD tier:
# asia-east1
# asia-east2 (Cheap)
# asia-northeast1
# asia-northeast3
# asia-south1
# asia-southeast1
# asia-southeast2
# australia-southeast1
# us-west1
# us-west2
# us-west3
# us-west4 (Cheapest)
# us-central1
# us-east1
# us-east4
# northamerica-northeast1
# southamerica-east1 (Cheap)
# europe-north1
# europe-west1
# europe-west2
# europe-west3
# europe-west4
# europe-west6

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