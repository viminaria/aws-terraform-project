# DynamoDB table for the application
resource "aws_dynamodb_table" "app" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = var.dynamodb_table_name
  }
}

# DynamoDB table for the Go API (id as partition key)
resource "aws_dynamodb_table" "go_api" {
  name         = var.go_api_dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = {
    Name = var.go_api_dynamodb_table_name
  }
}
