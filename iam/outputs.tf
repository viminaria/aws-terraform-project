output "instance_profile_name" {
  description = "IAM instance profile name for k3s nodes"
  value       = aws_iam_instance_profile.node.name
}

output "nginx_instance_profile_name" {
  description = "IAM instance profile name for NGINX"
  value       = aws_iam_instance_profile.nginx.name
}
