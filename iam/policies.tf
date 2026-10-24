# DynamoDB full access policy scoped to our table
resource "aws_iam_policy" "node_dynamodb" {
  name        = "${var.project_name}-node-dynamodb"
  description = "Allow EC2 nodes to access DynamoDB for the application"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/${var.dynamodb_table_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/${var.go_api_dynamodb_table_name}"
      }
    ]
  })
}

# S3 access policy scoped to our bucket
resource "aws_iam_policy" "node_s3" {
  name        = "${var.project_name}-node-s3"
  description = "Allow EC2 nodes to access S3 for the application"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::${var.s3_bucket_name}",
        "arn:aws:s3:::${var.s3_bucket_name}/*"
      ]
    }]
  })
}

# EC2 read policy — used by NGINX to discover k3s node IPs and by nodes for general operations
resource "aws_iam_policy" "ec2_read" {
  name        = "${var.project_name}-ec2-read"
  description = "Allow reading EC2 instance metadata for k3s cluster management"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:DescribeInstances",
        "ec2:DescribeTags"
      ]
      Resource = "*"
    }]
  })
}

data "aws_region" "current" {}
