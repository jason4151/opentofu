# remote_state/main.tf
# Bootstrap stack. Apply locally once; it is not part of setup-environment.yml.

terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.100"
    }
  }
}

provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      Environment = "lab"
      Owner       = "jason4151"
      Project     = "core-infra"
      CostCenter  = "lab"
    }
  }
}

resource "aws_s3_bucket" "tofu_state" {
  bucket = "opentofu-state-bucket-jason4151"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "tofu_state_versioning" {
  bucket = aws_s3_bucket.tofu_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tofu_state_encryption" {
  bucket = aws_s3_bucket.tofu_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tofu_state_public_access" {
  bucket = aws_s3_bucket.tofu_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "tofu_state_lock" {
  name         = "opentofu-state-lock-jason4151"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
