project_id  = "REPLACE_WITH_YOUR_PROJECT_ID"
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
helm_local_exec  = false