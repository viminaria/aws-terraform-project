output "dynamodb_table_arn" {
  description = "ARN of the application DynamoDB table"
  value       = aws_dynamodb_table.app.arn
}

output "go_api_dynamodb_table_name" {
  description = "Name of the Go API DynamoDB table"
  value       = aws_dynamodb_table.go_api.name
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.app.id
}
