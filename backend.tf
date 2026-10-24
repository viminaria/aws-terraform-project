# S3 bucket for Terraform remote state
resource "aws_s3_bucket" "tf_state" {
  bucket = "k3s-cluster-tf-state-${random_id.bucket_suffix.hex}"

  tags = {
    Name = "${var.project_name}-tf-state"
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# Block all public access on the state bucket
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning for state recovery
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# KMS encryption for state file (AWS-managed key)
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = "alias/aws/s3"
    }
  }
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
