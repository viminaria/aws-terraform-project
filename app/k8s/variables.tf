variable "dynamodb_tables" {
  description = "Map of app name to DynamoDB table name for environment variables"
  type        = map(string)
  default     = {}
}

variable "image_tag" {
  description = "Container image tag for the Go API (e.g., arm64-latest or a versioned digest)"
  type        = string
  default     = "arm64-latest"
}
