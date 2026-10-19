output "nginx_public_ip" {
  description = "Public IP of the NGINX load balancer — this is your cluster entry point"
  value       = module.compute.nginx_public_ip
}

output "nginx_dns" {
  description = "DNS name for the NGINX load balancer"
  value       = module.compute.nginx_dns
}

output "control_plane_private_ip" {
  description = "Private IP of the k3s control plane node (for internal access)"
  value       = module.compute.control_plane_private_ip
}

output "worker_private_ip" {
  description = "Private IP of the k3s worker node (for internal access)"
  value       = module.compute.worker_private_ip
}

output "k8s_access_url" {
  description = "How to access your cluster (use nginx public IP)"
  value = {
    api_server              = "https://${module.compute.nginx_public_ip}:6443"
    nodeport_base           = "${module.compute.nginx_public_ip}:30000-32767"
    kubeconfig_server_field = "--server=https://${module.compute.nginx_public_ip}:6443"
  }
}

output "dynamodb_table_arn" {
  description = "ARN of the DynamoDB table"
  value       = module.services.dynamodb_table_arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = module.services.s3_bucket_name
}

output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.networking.public_subnet_id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = module.networking.private_subnet_id
}
