# iam/provider.tf

provider "aws" {
  region = "us-east-2"
}

terraform {
  backend "s3" {
    # Partial backend config - bucket, key, region, and dynamodb_table will be provided at runtime
  }
}