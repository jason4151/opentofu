# ecr/provider.tf

provider "aws" {
  region = "us-east-2"  # Matches VPC and endpoints
}

terraform {
  backend "s3" {
    bucket         = "opentofu-state-bucket-jason4151"
    key            = "ecr/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "opentofu-state-lock-jason4151"
  }
}