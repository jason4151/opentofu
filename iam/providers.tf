# iam/provider.tf

provider "aws" {
  region = "us-east-2"
}

terraform {
  backend "s3" {
    bucket         = "opentofu-state-bucket-jason4151"
    key            = "iam/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "opentofu-state-lock-jason4151"
  }
}