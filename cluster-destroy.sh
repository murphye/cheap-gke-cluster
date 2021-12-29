region=${1:-us-west4}
zone=${2:-us-west4-a} 
network_name=${3:-my-network}
cluster_name=${4:-my-cluster}

gcloud beta compute forwarding-rules delete l7-xlb-forwarding-rule-http --region ${region} --quiet
gcloud compute addresses delete my-static-ip --region=${region} --quiet
gcloud beta compute target-http-proxies delete l7-xlb-proxy-http --region=${region} --quiet
gcloud beta compute url-maps delete regional-l7-xlb-map-http --region=${region} --quiet
gcloud beta compute backend-services remove-backend l7-xlb-backend-service-http \
    --network-endpoint-group=istio-ingressgateway \
    --network-endpoint-group-zone=${zone} \
    --region=${region}
gcloud beta compute backend-services delete l7-xlb-backend-service-http --region=${region} --quiet
gcloud beta compute health-checks delete l7-xlb-basic-check-http --region=${region} --quiet
gcloud beta compute firewall-rules delete fw-allow-proxies --quiet
gcloud compute firewall-rules delete fw-allow-health-check-and-proxy --quiet

gcloud compute routers nats delete nat-config --router nat-router --region ${region}  --quiet
gcloud compute routers delete nat-router --region ${region} --quiet

gcloud container clusters delete ${cluster_name} --zone ${zone} --quiet
gcloud compute network-endpoint-groups delete istio-ingressgateway --zone ${zone} --quiet
gcloud beta compute networks subnets delete proxy-only-subnet --region ${region}  --quiet

gcloud beta compute networks delete ${network_name} --quiet
