# S3 bucket + DynamoDB for real AWS — disabled for Floci staging
# Uncomment when deploying to real AWS:
# resource "aws_s3_bucket" "tf_state" { ... }
# resource "aws_dynamodb_table" "tf_lock" { ... }


# Backend configuration — uncomment after first apply:
# 1. Run `terraform apply` with this file commented out (creates S3 bucket + DynamoDB)
# 2. Copy the bucket name from terraform output: terraform output -raw aws_s3_bucket.tf_state.id
# 3. Uncomment this block, replace <actual-bucket-name>, run `terraform init -migrate-state`
# terraform {
#   backend "s3" {
#     bucket         = "<actual-s3-bucket-name-from-output>"
#     key            = "terraform.tfstate"
#     region         = "eu-central-1"
#     dynamodb_table = "k3s-cluster-tf-lock"
#     encrypt        = true
#   }
# }
