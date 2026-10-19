# Emulated ECR repository for k3s container images (push from host before terraform apply)
resource "aws_ecr_repository" "k3s" {
  name = "${var.project_name}-k3s-images"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

output "ecr_k3s_repository_url" {
  description = "ECR repository URI for k3s images (for push from host machine)"
  value       = aws_ecr_repository.k3s.repository_url
}
