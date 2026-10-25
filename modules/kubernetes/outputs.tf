output "apply_instructions" {
  description = "How to apply this module without exposing the k8s API publicly"
  value       = <<EOT
Run these steps:

1. Extract kubeconfig via SSH (one-time):
   ./compute/scripts/extract_k8s_certs.sh <nginx_public_ip> <control_plane_private_ip>

2. Set env var with kubeconfig content:
   export KUBECONFIG_CONTENT="$(cat ~/.kube/k3s-cluster)"

3. Get Terraform variables:
   cd ~/aws-terraform-project
   TF_VAR_aws_region=$(terraform output -raw aws_region 2>/dev/null || echo "eu-north-1")
   TF_VAR_go_api_dynamodb_table_name=$(terraform output -raw go_api_dynamodb_table_name 2>/dev/null || echo "k3s-cluster-go-api-items")

4. Apply:
   cd modules/kubernetes
   KUBECONFIG_CONTENT="$KUBECONFIG_CONTENT" \
     TF_VAR_ingress_subdomains='{"go-api": "go-api"}' \
     TF_VAR_dynamodb_tables='{"go-api": "'$TF_VAR_go_api_dynamodb_table_name'"}' \
     terraform apply -var="kubeconfig_content=$KUBECONFIG_CONTENT"
EOT
}
