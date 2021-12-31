# How to Build and Run a Cheap GKE Cluster

See this blog post for a detailed explanation: TODO

## How Cheap is it?

You can run a 3 node, 6 core GKE cluster for about USD $24.00 in a region with a 90% discount on `e2-standard-2` Spot VM instances. Every possible measure for cost cutting has been taken while still having a 
very usable GKE cluster.

**Warning:** Google Cloud gives you 1 free GKE control plane. If you run more than 1 GKE cluster, you will incur $74.40 per month for each control plane!

## Setup

Change `terraform.tfvars` to use your Google Cloud `PROJECT_ID`. You can find your `PROJECT_ID` by running this command:

```
gcloud projects list
```

You should also update your current project for `gcloud` if it's not set to the one that you intend to deploy the cluster to:

```
gcloud config set project REPLACE_WITH_YOUR_PROJECT_ID
```
You may also choose to change the region you choose to deploy. Each GCP region has different pricing for VM Spot instances. See this [page](https://cloud.google.com/compute/vm-instance-pricin) for pricing details.

### Install Terraform (If Needed)

Terraform is required to run the deployment. On a Mac you can use Homebrew by running these commands:

```
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

## Run the Deployment

```
cd terraform
terraform init
terraform apply --auto-approve
kubectl apply -f ../petstore.yaml
kubectl apply -f ../virtualservice.yaml
```

Get the IP Address of the load balancer for running the `curl` command to verify deployment. Change the `my-static-ip` if it was changed in the `terraform.tfvars`
```
ipaddress=$(gcloud compute addresses describe my-static-ip --format="value(address)")
```

Run the curl command. You should see JSON data from the Petstore application.
```
curl http://$ipaddress

[{"id":1,"name":"Dog","status":"available"},{"id":2,"name":"Cat","status":"pending"}]
```

## How Does it Work?

The overall solution is a bit complex and does use some Beta features of Google Cloud. The solution has been implemented in Terraform to make it easy to deploy. More details are available in the blog post.

These are the main parts of the solution to achieve a high level of cost savings:

1. Use a private GKE cluster using only Spot VM instances as the cluster nodes. This will save you up to 90% on the cost of VMs, depending on the region. This could save you up to $150 per month for GKE node VMs for a 3 node, 6 core cluster.
2. Use a Regional (rather than Global) HTTP Load Balancer which is currently free as a Beta preview. Additional costs may be incurred in the future. This currently saves you $18.26 per month.
3. The 1st GKE control plane is free. This currently saves $74.40 per month.

Terraform configs (`.tf`) are commented with specific details and references to explain how the deployment works and why. Also see the blog post for specifics.

## Next Steps For Using Your Cheap GKE Cluster

### Deplying an Application and Using Gloo Edge to Route Traffic

[Gloo Edge](https://docs.solo.io/gloo-edge/master/) provides powerful traffic routing capabilities that go far beyond the standard [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/). As Gloo Edge uses Envoy, capabilities such as retries help improve the resiliency of routing to applications in your cluster that is using Spot VM node instances.

It's beneficial, but not required, to [install `glooctl`](https://docs.solo.io/gloo-edge/master/installation/glooctl_setup/) to work with Gloo Edge.

1. Read the blog post linked at the top of this `README.md`
2. Examine `virtualservice.yaml` and [understand how it works](https://docs.solo.io/gloo-edge/master/introduction/traffic_management/).
3. Deploy your own application onto your new Kubernetes cluster.
4. Modify `virtualservice.yaml` to use your application's upstream. You can view upstreams with `glooctl get upstream`.
