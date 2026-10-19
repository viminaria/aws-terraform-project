variable "project_name" {
  description = "Project name"
  type        = string
}

variable "dynamodb_table_name" {
  description = "DynamoDB table name for the app"
  type        = string
}

variable "go_api_dynamodb_table_name" {
  description = "DynamoDB table name for the Go API"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name for the app"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
