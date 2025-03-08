# s3_state_bucket/provider.tf

provider "aws" {
  region = "us-east-2"
}

terraform {
  backend "s3" {
    # Bucket, key, region, and dynamodb_table provided by workflow secrets
  }
}