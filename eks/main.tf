# eks/main.tf

# Fetch the VPC module outputs using remote state
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket         = "opentofu-state-bucket-jason4151"
    key            = "vpc/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "opentofu-state-lock-jason4151"
  }
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster" {
  name = "lab-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
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

# Attach policies to EKS Cluster Role
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_node_group" {
  name = "lab-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "lab-eks-node-group-role"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Attach policies to EKS Node Group Role
resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_readonly" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# EKS Cluster
resource "aws_eks_cluster" "main" {
  name     = "lab-eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.28" # Pin to a specific version

  vpc_config {
    subnet_ids              = data.terraform_remote_state.vpc.outputs.private_subnet_ids
    endpoint_public_access  = var.enable_public_endpoint
    endpoint_private_access = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name        = "lab-eks-cluster"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "lab-node-group"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = [data.terraform_remote_state.vpc.outputs.private_subnet_ids[0]]

  scaling_config {
    desired_size = var.node_desired_size # Default 1 from variables.tf
    max_size     = var.node_max_size
    min_size     = var.node_min_size
  }

  instance_types = ["t3.micro"] # Smaller instance for lab
  capacity_type  = "SPOT"       # Use Spot for cost savings

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_readonly
  ]

  tags = {
    Name        = "lab-eks-node-group"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Data source to fetch the Auto Scaling Group created by EKS
data "aws_autoscaling_groups" "eks_node_group" {
  filter {
    name   = "tag:eks:cluster-name"
    values = [aws_eks_cluster.main.name]
  }

  filter {
    name   = "tag:eks:nodegroup-name"
    values = [aws_eks_node_group.main.node_group_name]
  }

  depends_on = [aws_eks_node_group.main]
}

# Apply tags to the Auto Scaling Group and propagate to EC2 instances using for_each
resource "aws_autoscaling_group_tag" "node_tags" {
  for_each = {
    "Name"        = "lab-eks-node"
    "Environment" = "lab"
    "Owner"       = "jason4151"
    "Project"     = "core-infra"
    "CostCenter"  = "lab"
  }

  autoscaling_group_name = data.aws_autoscaling_groups.eks_node_group.names[0]

  tag {
    key                 = each.key
    value               = each.value
    propagate_at_launch = true
  }
}

# Security Group for EKS Nodes
resource "aws_security_group" "eks_nodes" {
  name        = "lab-eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  ingress {
    description = "Allow all traffic within the SG (node-to-node)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  ingress {
    description = "Allow Kubernetes API from VPC CIDR"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.terraform_remote_state.vpc.outputs.vpc_cidr_block]
  }

  egress {
    description = "Allow outbound HTTPS to AWS services (ECR/S3/SSM)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # NAT Gateway + Endpoints handle this
  }

  egress {
    description = "Allow all traffic within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [data.terraform_remote_state.vpc.outputs.vpc_cidr_block]
  }

  tags = {
    Name        = "lab-eks-nodes-sg"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}