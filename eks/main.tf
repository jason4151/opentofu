# eks/main.tf
# EKS Auto Mode lab cluster. Fresh apply is expected; do not apply this
# over leftover managed-node-group state from the old eks/ stack.

data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket         = "opentofu-state-bucket-jason4151"
    key            = "vpc/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "opentofu-state-lock-jason4151"
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "eks_cluster" {
  name = "lab-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })

  tags = {
    Name = "lab-eks-cluster-role"
  }
}

locals {
  eks_cluster_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSComputePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy",
  ]
}

resource "aws_iam_role_policy_attachment" "eks_cluster" {
  for_each   = toset(local.eks_cluster_policies)
  role       = aws_iam_role.eks_cluster.name
  policy_arn = each.value
}

resource "aws_iam_role" "eks_auto_node" {
  name = "lab-eks-auto-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name = "lab-eks-auto-node-role"
  }
}

locals {
  eks_node_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
  ]
}

resource "aws_iam_role_policy_attachment" "eks_auto_node" {
  for_each   = toset(local.eks_node_policies)
  role       = aws_iam_role.eks_auto_node.name
  policy_arn = each.value
}

resource "aws_eks_cluster" "main" {
  name                          = "lab-eks-cluster"
  role_arn                      = aws_iam_role.eks_cluster.arn
  version                       = "1.34"
  bootstrap_self_managed_addons = false

  access_config {
    authentication_mode = "API"
  }

  compute_config {
    enabled       = true
    node_pools    = ["general-purpose", "system"]
    node_role_arn = aws_iam_role.eks_auto_node.arn
  }

  kubernetes_network_config {
    elastic_load_balancing {
      enabled = true
    }
  }

  storage_config {
    block_storage {
      enabled = true
    }
  }

  vpc_config {
    subnet_ids = concat(
      data.terraform_remote_state.vpc.outputs.private_subnet_ids,
      data.terraform_remote_state.vpc.outputs.public_subnet_ids
    )
    endpoint_public_access  = true
    endpoint_private_access = true
    public_access_cidrs     = [var.public_endpoint_cidr]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster,
    aws_iam_role_policy_attachment.eks_auto_node,
  ]

  tags = {
    Name = "lab-eks-cluster"
  }
}

resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/jason4151"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.admin.principal_arn

  access_scope {
    type = "cluster"
  }
}

resource "aws_eks_access_entry" "github" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/GitHubActionsRole"
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "github" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = aws_eks_access_entry.github.principal_arn

  access_scope {
    type = "cluster"
  }
}
