variable "dynamodb_table_name" {
  description = "DynamoDB table name"
  type        = string
}

variable "go_api_dynamodb_table_name" {
  description = "Go API DynamoDB table name"
  type        = string
}

variable "s3_bucket_name" {
  description = "S3 bucket name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}
