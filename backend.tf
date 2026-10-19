# S3 bucket for Terraform remote state
resource "aws_s3_bucket" "tf_state" {
  bucket = "k3s-cluster-tf-state-${random_id.bucket_suffix.hex}"

}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# DynamoDB table for state locking
resource "aws_dynamodb_table" "tf_lock" {
  name         = "k3s-cluster-tf-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

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
