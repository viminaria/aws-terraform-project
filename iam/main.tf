# IAM role for k3s nodes (access DynamoDB and S3)
resource "aws_iam_role" "node" {
  name = "${var.project_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-node-role"
  }
}

# Attach policies to the role
resource "aws_iam_role_policy_attachment" "dynamodb" {
  policy_arn = aws_iam_policy.node_dynamodb.arn
  role       = aws_iam_role.node.name
}

resource "aws_iam_role_policy_attachment" "s3" {
  policy_arn = aws_iam_policy.node_s3.arn
  role       = aws_iam_role.node.name
}

# Instance profile to associate with k3s nodes (control plane + worker)
resource "aws_iam_instance_profile" "node" {
  name = "${var.project_name}-node-profile"
  role = aws_iam_role.node.name
}

# Minimal IAM role for NGINX — EC2 read for instance discovery
resource "aws_iam_role" "nginx" {
  name = "${var.project_name}-nginx-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${var.project_name}-nginx-role"
  }
}

resource "aws_iam_role_policy_attachment" "nginx_ec2" {
  policy_arn = aws_iam_policy.ec2_read.arn
  role       = aws_iam_role.nginx.name
}

# Instance profile for NGINX
resource "aws_iam_instance_profile" "nginx" {
  name = "${var.project_name}-nginx-profile"
  role = aws_iam_role.nginx.name
}
