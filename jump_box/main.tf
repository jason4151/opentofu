# jump_box/main.tf

# Data source to fetch VPC state from S3
data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket         = "opentofu-state-bucket-jason4151"
    key            = "vpc/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "opentofu-state-lock-jason4151" # Assuming you have this for consistency
  }
}

# Fetch the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM Role for SSM Session Manager
resource "aws_iam_role" "jump_box_ssm" {
  name = "jump-box-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "jump-box-ssm-role"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Attach SSM Managed Policy to the Role
resource "aws_iam_role_policy_attachment" "jump_box_ssm_policy" {
  role       = aws_iam_role.jump_box_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance Profile for the EC2
resource "aws_iam_instance_profile" "jump_box" {
  name = "jump-box-profile"
  role = aws_iam_role.jump_box_ssm.name
}

# Security Group for the Jump Box
resource "aws_security_group" "jump_box" {
  name        = "jump-box-sg"
  description = "Security group for jump-box EC2"
  vpc_id      = data.terraform_remote_state.vpc.outputs.vpc_id

  # Egress to internet for SSM (HTTPS) and other needs via NAT Gateway
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # NAT Gateway handles outbound routing
  }

  tags = {
    Name        = "jump-box-sg"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# EC2 Instance (Jump Box)
resource "aws_instance" "jump_box" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.nano"
  subnet_id              = data.terraform_remote_state.vpc.outputs.private_subnet_ids[0] # Moved to private-subnet-0
  iam_instance_profile   = aws_iam_instance_profile.jump_box.name
  vpc_security_group_ids = [aws_security_group.jump_box.id]
  # No associate_public_ip_address since it's in a private subnet and uses NAT Gateway

  tags = {
    Name        = "jump-box"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}