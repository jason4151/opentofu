# eks/provider.tf

provider "aws" {
  region = "us-east-2"
}

provider "kubernetes" {
  host                   = aws_eks_cluster.main.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.main.certificate_authority[0].data)
  exec {
    api_version = "client.authentication.k8s.io/v1"
    args        = ["eks", "get-token", "--cluster-name", aws_eks_cluster.main.name]
    command     = "aws"
  }
}

terraform {
  backend "s3" {
    # Bucket, key, region, and dynamodb_table provided by workflow secrets
  }
}