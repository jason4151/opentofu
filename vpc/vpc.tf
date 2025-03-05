# Define the VPC with a configurable /22 CIDR (1,024 IPs)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true  # Needed for VPC endpoints and DNS resolution
  enable_dns_hostnames = true  # Ensures proper DNS for private hosted zones and endpoints

  tags = {
    Name        = "main-vpc"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Restrict the default security group to deny all traffic
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # No ingress/egress rules means deny all by default, forcing explicit SGs
  tags = {
    Name        = "default-sg"
    Environment = "lab"
  }
}

# Internet Gateway for public subnets
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "main-igw"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Fetch 3 Availability Zones in us-east-2
data "aws_availability_zones" "available" {
  state = "available"
}

# Public Subnets (3 x /26 for efficiency)
resource "aws_subnet" "public" {
  count = 3

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 4, count.index)  # /26 (64 IPs) carved from /22
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "public-subnet-${count.index}"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Private Subnets (3 x /26 for efficiency)
resource "aws_subnet" "private" {
  count = 3

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr_block, 4, count.index + 3)  # Offset by 3, still /26
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "private-subnet-${count.index}"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Elastic IP for NAT Gateway(s)
resource "aws_eip" "nat" {
  count = var.ha_nat_gateways ? 3 : 1  # Single EIP unless HA is enabled

  tags = {
    Name        = "nat-eip-${count.index}"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# NAT Gateway(s) for private subnets, placed in AZ 0 for single NAT
resource "aws_nat_gateway" "nat" {
  count = var.ha_nat_gateways ? 3 : 1

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = var.ha_nat_gateways ? aws_subnet.public[count.index].id : aws_subnet.public[0].id  # Single NAT in AZ 0

  tags = {
    Name        = "nat-gateway-${count.index}"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "public-rt"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Associate public subnets with the public route table
resource "aws_route_table_association" "public" {
  count = 3

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table for Private Subnets
resource "aws_route_table" "private" {
  count = var.ha_nat_gateways ? 3 : 1  # One per NAT if HA, otherwise shared

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name        = "private-rt-${count.index}"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Associate private subnets with their route tables
resource "aws_route_table_association" "private" {
  count = 3

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.ha_nat_gateways ? aws_route_table.private[count.index].id : aws_route_table.private[0].id
}

# Network ACL with rules adjusted for public web traffic
resource "aws_network_acl" "main" {
  vpc_id = aws_vpc.main.id

  # Allow HTTP inbound from anywhere for public subnets
  ingress {
    protocol   = "tcp"
    rule_no    = 90   # Lower rule number to prioritize over HTTPS
    action     = "allow"
    cidr_block = "0.0.0.0/0"  # Allow from internet
    from_port  = 80
    to_port    = 80
  }

  # Allow HTTPS inbound from anywhere for public subnets
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"  # Allow from internet
    from_port  = 443
    to_port    = 443
  }

  # Allow ephemeral ports for return traffic from anywhere
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"  # Match inbound rules for return traffic
    from_port  = 1024
    to_port    = 65535
  }

  # Allow HTTP outbound for responses
  egress {
    protocol   = "tcp"
    rule_no    = 90
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  # Allow HTTPS outbound for responses
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  tags = {
    Name        = "main-nacl"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Associate NACL with all subnets
resource "aws_network_acl_association" "public" {
  count = 3

  subnet_id      = aws_subnet.public[count.index].id
  network_acl_id = aws_network_acl.main.id
}

resource "aws_network_acl_association" "private" {
  count = 3

  subnet_id      = aws_subnet.private[count.index].id
  network_acl_id = aws_network_acl.main.id
}

# VPC Endpoint for S3 (Gateway, free, keeps traffic internal)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-2.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(aws_route_table.public[*].id, aws_route_table.private[*].id)

  tags = {
    Name        = "s3-endpoint"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# VPC Endpoint for DynamoDB (Gateway, free)
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-2.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(aws_route_table.public[*].id, aws_route_table.private[*].id)

  tags = {
    Name        = "dynamodb-endpoint"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# VPC Endpoint for ECR (Interface, reduces NAT costs for container pulls)
resource "aws_vpc_endpoint" "ecr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-2.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.ecr_endpoint.id]
  private_dns_enabled = true  # Maps ECR DNS to private IPs

  tags = {
    Name        = "ecr-endpoint"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Security Group for ECR Endpoint
resource "aws_security_group" "ecr_endpoint" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]  # Allow HTTPS from VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "ecr-endpoint-sg"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# VPC Flow Logs with compression for cost savings
resource "aws_flow_log" "vpc_flow" {
  vpc_id            = aws_vpc.main.id
  traffic_type      = "ALL"
  iam_role_arn      = aws_iam_role.flow_log_role.arn
  log_destination   = aws_cloudwatch_log_group.vpc_flow.arn
  log_format        = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status}"
  destination_options {
    file_format = "parquet"  # Compresses logs to reduce CloudWatch storage costs
  }

  tags = {
    Name        = "vpc-flow-logs"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# CloudWatch Log Group with retention for cost control
resource "aws_cloudwatch_log_group" "vpc_flow" {
  name              = "vpc-flow-logs"
  retention_in_days = 30  # Limits storage costs to 30 days of logs

  tags = {
    Environment = "lab"
    Project     = "core-infra"
  }
}

# IAM Role for VPC Flow Logs
resource "aws_iam_role" "flow_log_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "vpc-flow-logs.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "flow-log-role"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# IAM Policy for Flow Logs to write to CloudWatch
resource "aws_iam_role_policy" "flow_log_policy" {
  role = aws_iam_role.flow_log_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Effect   = "Allow"
      Resource = aws_cloudwatch_log_group.vpc_flow.arn
    }]
  })
}