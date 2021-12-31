# How to Build and Run a Cheap GKE Cluster

See this blog post for a detailed explanation: TODO

Terraform configs (`.tf`) are commented with specific details and references to explain how the deployment works and why.

## Deploy Cheap Kubernetes Cluster with Load Balancer, and Petstore Application

Change `terraform.tfvars` to use your Google Cloud `PROJECT_ID`. You can find your `PROJECT_ID` by running this command:

```
gcloud projects list
```

You should also update your current project for `gcloud` if it's not set to the one that you intend to deploy the cluster to:

```
gcloud config set project REPLACE_WITH_YOUR_PROJECT_ID
```

### Install Terraform (If Needed)

Terraform is required to run the deployment. On a Mac you can use Homebrew by running these commands:

```
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

### Run the Deployment

```
terraform init
terraform apply
kubectl apply -f petstore.yaml
```

Get the IP Address of the load balancer for running the `curl` command to verify deployment. Change the `my-static-ip` if it was changed in the `terraform.tfvars`
```
ipaddress=$(gcloud compute addresses describe my-static-ip --format="value(address)")
```

Run the curl command. You should see JSON in the response from the Petstore application.
```
curl -v http://${ipaddress}/
```


