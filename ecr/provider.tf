# ecr/provider.tf

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    # Bucket, key, region, and dynamodb_table provided by workflow secrets
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
