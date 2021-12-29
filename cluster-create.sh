# In order to more easily track billing for your new cheap cluster, you may want to create a new Google Cloud project.
# Make sure your gcloud is set for the correct project!

# Example of use:
# ./cluster-create.sh asia-east2 asia-east2-a 
# See this page for lowest spot prices: https://cloud.google.com/compute/vm-instance-pricing
region=${1:-us-west4}
zone=${2:-us-west4-a} 
network_name=${3:-my-network}
cluster_name=${4:-my-cluster}
static_ip_name=${5:-my-static-ip}
machine_type=${6:-e2-standard-2}
num_cluster_nodes=${7:-3}
disk_size=${8:-"20"}
istio_version=${9:-1.12.1}
health_check_request_path=${10:-/productpage}

gcloud compute networks create ${network_name}

gcloud beta compute networks subnets create proxy-only-subnet \
    --purpose=REGIONAL_MANAGED_PROXY \
    --role=ACTIVE \
    --region=${region} \
    --network=${network_name} \
    --range=11.129.0.0/23

gcloud beta container clusters create ${cluster_name} \
    --enable-ip-alias \
    --enable-private-nodes \
    --disable-default-snat \
    --no-enable-master-authorized-networks \
    --zone=${zone}  \
    --network=${network_name} \
    --create-subnetwork name=${cluster_name}-subnet,range=10.0.0.0/24 \
    --cluster-ipv4-cidr=5.0.0.0/16 \
    --services-ipv4-cidr=5.1.0.0/16 \
    --master-ipv4-cidr=172.16.0.16/28 \
    --machine-type=${machine_type} \
    --num-nodes=${num_cluster_nodes} \
    --tags=${cluster_name} \
    --disk-size=${disk_size} \
    --logging=NONE \
    --spot

gcloud compute routers create nat-router \
	--network ${network_name} \
	--region ${region}

gcloud compute routers nats create nat-config \
	--router-region ${region} \
	--router nat-router \
	--nat-all-subnet-ip-ranges \
	--auto-allocate-nat-external-ips

curl -L https://istio.io/downloadIstio | ISTIO_VERSION=${istio_version} sh -
cd istio-${istio_version}
export PATH=$PWD/bin:$PATH

istioctl install --set values.gateways.istio-ingressgateway.type=ClusterIP -y

kubectl annotate -n istio-system --overwrite service istio-ingressgateway cloud.google.com/neg='{"exposed_ports": {"80":{"name": "istio-ingressgateway"}}}'

# Install Bookinfo Application
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.12/samples/bookinfo/platform/kube/bookinfo.yaml

# Install Istio Bookinfo Gateway
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.12/samples/bookinfo/networking/bookinfo-gateway.yaml

gcloud compute firewall-rules create fw-allow-health-check-and-proxy \
    --network=${network_name} \
    --action=allow \
    --direction=ingress \
    --target-tags=${cluster_name} \
    --source-ranges=130.211.0.0/22,35.191.0.0/16 \
    --rules=tcp:8080,tcp:8443

gcloud beta compute firewall-rules create fw-allow-proxies \
    --network=${network_name} \
    --action=allow \
    --direction=ingress \
    --source-ranges=11.129.0.0/23 \
    --target-tags=${cluster_name} \
    --rules=tcp:8080,tcp:8443

gcloud beta compute health-checks create http l7-xlb-basic-check-http \
    --region=${region} \
    --request-path='/productpage' \
    --use-serving-port

gcloud beta compute backend-services create l7-xlb-backend-service-http \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --protocol=HTTP \
    --port-name=http \
    --health-checks=l7-xlb-basic-check-http \
    --health-checks-region=${region} \
    --region=${region}

gcloud beta compute backend-services add-backend l7-xlb-backend-service-http \
    --network-endpoint-group=istio-ingressgateway \
    --network-endpoint-group-zone=${zone} \
    --region=${region} \
    --balancing-mode RATE \
    --max-rate-per-endpoint 3500

gcloud beta compute url-maps create regional-l7-xlb-map-http \
    --default-service=l7-xlb-backend-service-http \
    --region=${region}

gcloud beta compute target-http-proxies create l7-xlb-proxy-http \
    --url-map=regional-l7-xlb-map-http \
    --url-map-region=${region} \
    --region=${region}

gcloud compute addresses create my-static-ip --network-tier=STANDARD --region=${region}

gcloud beta compute forwarding-rules create l7-xlb-forwarding-rule-http \
    --load-balancing-scheme=EXTERNAL_MANAGED \
    --network-tier=STANDARD \
    --network=${network_name} \
    --ports=80 \
    --region=${region} \
    --target-http-proxy=l7-xlb-proxy-http \
    --target-http-proxy-region=${region} \
    --address=${static_ip_name}

ipaddress=$(gcloud compute addresses describe ${static_ip_name} --region=${region} --format="value(address)")

echo "View Bookinfo in your browser with this url:"
echo "http://${ipaddress}/productpage"