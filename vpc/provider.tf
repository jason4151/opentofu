# vpc/provider.tf

# AWS Provider configuration
provider "aws" {
  region = "us-east-2"  # Matches VPC and endpoint region
}

# Terraform backend configuration for S3 state storage
terraform {
  backend "s3" {
    bucket = "opentofu-state-bucket-jason4151"  # Your state bucket
    key    = "vpc/terraform.tfstate"            # State file path for VPC
    region = "us-east-2"                        # Matches provider region
  }
}