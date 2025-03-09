# remote_state/main.tf

provider "aws" {
  region = "us-east-2"
}

# Create an S3 bucket to store OpenTofu state files
resource "aws_s3_bucket" "tofu_state" {
  bucket = "opentofu-state-bucket-jason4151"

  # Prevent accidental deletion of the bucket
  lifecycle {
    prevent_destroy = true
  }
}

# Enable versioning on the bucket to protect state file history
resource "aws_s3_bucket_versioning" "tofu_state_versioning" {
  bucket = aws_s3_bucket.tofu_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Apply server-side encryption to secure state files
resource "aws_s3_bucket_server_side_encryption_configuration" "tofu_state_encryption" {
  bucket = aws_s3_bucket.tofu_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block all public access to the bucket for security
resource "aws_s3_bucket_public_access_block" "tofu_state_public_access" {
  bucket = aws_s3_bucket.tofu_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Create a DynamoDB table for state locking to prevent concurrent edits
resource "aws_dynamodb_table" "tofu_state_lock" {
  name         = "opentofu-state-lock-jason4151"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}