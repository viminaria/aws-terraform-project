output "nginx_public_ip" {
  description = "Public IP of NGINX load balancer"
  value       = aws_eip.nginx.public_ip
}

output "nginx_dns" {
  description = "DNS name of NGINX load balancer"
  value       = aws_instance.nginx.public_dns
}

output "control_plane_private_ip" {
  description = "Private IP of k3s control plane"
  value       = aws_instance.control_plane.private_ip
}

output "worker_private_ip" {
  description = "Private IP of k3s worker"
  value       = aws_instance.worker.private_ip
}
