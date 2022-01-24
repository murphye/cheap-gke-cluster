# If you have enabled HTTPS and want to update the SSL certificate, this script will help make it easier to do the swap.

# Update these values for your use!
region="us-west4"
cert_name="my-cert"
tmp_cert_name="my-tmp-cert"
private_key_file="terraform/certs/self-signed.key"
certificate_file="terraform/certs/self-signed.crt"

# Create a temporary ssl-certificate
gcloud compute ssl-certificates create $tmp_cert_name --certificate $certificate_file --private-key $private_key_file --region $region
gcloud compute target-https-proxies update l7-xlb-proxy-https --ssl-certificates $tmp_cert_name --region $region
gcloud compute ssl-certificates delete $cert_name --region $region --quiet

# Update again to change the ssl-certificate name back to the original name, so there is not an error when running `terraform destroy``
gcloud compute ssl-certificates create $cert_name --certificate $certificate_file --private-key $private_key_file --region $region
gcloud compute target-https-proxies update l7-xlb-proxy-https --ssl-certificates $cert_name --region $region
gcloud compute ssl-certificates delete $tmp_cert_name --region $region --quiet