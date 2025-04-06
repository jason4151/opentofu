# eks/main.tf

# Fetch VPC details from remote state in S3
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket         = "opentofu-state-bucket-jason4151"
    key            = "vpc/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "opentofu-state-lock-jason4151"
  }
}

# Get current AWS account ID
data "aws_caller_identity" "current" {}

# IAM Role for EKS Cluster
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
    Name        = "lab-eks-cluster-role"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Attach EKS Cluster Policy
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# Custom Policy for EKS Auto Mode
resource "aws_iam_role_policy" "eks_auto_mode_policy" {
  name   = "EKSAutoModePolicy"
  role   = aws_iam_role.eks_cluster.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:*", "elasticloadbalancing:*", "autoscaling:*", "ebs:*", "eks:UpdateClusterConfig", "eks:Describe*"]
        Resource = "*"
      }
    ]
  })
}

# EKS Cluster with Auto Mode Enabled
resource "aws_eks_cluster" "main" {
  name     = "lab-eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.32"

  bootstrap_self_managed_addons = false

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  compute_config {
    enabled = true
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
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy.eks_auto_mode_policy
  ]

  tags = {
    Name        = "lab-eks-cluster"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Access Entry for Your Local Admin User
resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/jason4151"
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.main]
}

# Access Policy for Admin User (Cluster Admin)
resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/jason4151"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}

# Access Entry for GitHub Actions Role
resource "aws_eks_access_entry" "github" {
  cluster_name  = aws_eks_cluster.main.name
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/GitHubActionsRole"
  type          = "STANDARD"

  depends_on = [aws_eks_cluster.main]
}

# Access Policy for GitHub Actions Role (Cluster Admin)
resource "aws_eks_access_policy_association" "github" {
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/GitHubActionsRole"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.github]
}

# Delay to Ensure Access is Propagated
resource "null_resource" "access_delay" {
  provisioner "local-exec" {
    command = "sleep 30"  # Wait 30 seconds
  }

  depends_on = [
    aws_eks_access_policy_association.admin,
    aws_eks_access_policy_association.github
  ]
}

# Update aws-auth ConfigMap for user access
resource "kubernetes_config_map" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapUsers = yamlencode([
      {
        userarn  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/jason4151"
        username = "jason4151"
        groups   = ["system:masters"]
      }
    ])
  }

  depends_on = [
    aws_eks_access_policy_association.admin,
    aws_eks_access_policy_association.github,
    null_resource.access_delay
  ]
}