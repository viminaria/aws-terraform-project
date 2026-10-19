# ECR repository for Go API container images
resource "aws_ecr_repository" "go_api" {
  name                 = "${var.project_name}-go-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }
}

output "ecr_go_api_repository_url" {
  description = "ECR repository URI for Go API images"
  value       = aws_ecr_repository.go_api.repository_url
}
