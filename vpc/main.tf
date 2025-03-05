# vpc/main.tf

# Fetch current AWS account ID for outputs
data "aws_caller_identity" "current" {}

# Fetch 2 Availability Zones in us-east-2 for subnet placement
data "aws_availability_zones" "available" {
  state = "available"
}

# VPC with configurable CIDR
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block # e.g., 10.33.0.0/22
  enable_dns_support   = true               # Needed for VPC endpoints and DNS resolution
  enable_dns_hostnames = true               # Ensures proper DNS for private hosted zones and endpoints

  tags = {
    Name        = "lab-vpc"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Default Security Group (locked down)
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  # No ingress/egress rules defined, denying all traffic by default to force explicit SGs
  tags = {
    Name        = "lab-default-sg"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Default Route Table (managed, unused)
resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  # No routes defined to keep it unused and clean
  tags = {
    Name        = "lab-default-rt"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Default NACL (managed, unused)
resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.main.default_network_acl_id

  # No rules defined, remains unused as custom NACL is applied
  tags = {
    Name        = "lab-default-nacl"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Custom DHCP Option Set with AWS DNS and NTP
resource "aws_vpc_dhcp_options" "default" {
  domain_name_servers = ["AmazonProvidedDNS"] # AWS-provided DNS servers
  ntp_servers         = ["169.254.169.123"]   # Amazon Time Sync Service

  tags = {
    Name        = "lab-default-dhcp"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# DHCP Option Set Association
resource "aws_vpc_dhcp_options_association" "default" {
  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.default.id
}

# Internet Gateway for public subnets
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "lab-igw"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Public Subnets (2 x /26 across 2 AZs)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 4, count.index) # /26 (64 IPs)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "lab-public-subnet-${count.index}"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Private Subnets (2 x /26 across 2 AZs)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr_block, 4, count.index + 2) # Offset by 2, still /26
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "lab-private-subnet-${count.index}"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Elastic IP for NAT Gateway (conditional)
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.ha_nat_gateways ? 2 : 1) : 0

  tags = {
    Name        = "lab-nat-eip-${count.index}"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# NAT Gateway (conditional)
resource "aws_nat_gateway" "nat" {
  count         = var.enable_nat_gateway ? (var.ha_nat_gateways ? 2 : 1) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = var.ha_nat_gateways ? aws_subnet.public[count.index].id : aws_subnet.public[0].id

  tags = {
    Name        = "lab-nat-gateway-${count.index}"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "lab-public-rt-0"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Public Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table (conditional HA)
resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway && var.ha_nat_gateways ? 2 : 1
  vpc_id = aws_vpc.main.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.nat[count.index].id
    }
  }

  tags = {
    Name        = "lab-private-rt-${count.index}"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.enable_nat_gateway && var.ha_nat_gateways ? aws_route_table.private[count.index].id : aws_route_table.private[0].id
}

# Network ACL with traffic rules
resource "aws_network_acl" "main" {
  vpc_id = aws_vpc.main.id

  # Allow inbound HTTP traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 90
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  # Allow inbound HTTPS traffic
  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  # Allow inbound return traffic from internet services
  ingress {
    protocol   = "tcp"
    rule_no    = 120
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  # Allow outbound HTTP traffic
  egress {
    protocol   = "tcp"
    rule_no    = 90
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  # Allow outbound HTTPS traffic
  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  # Allow outbound ephemeral ports for internet traffic
  egress {
    protocol   = "tcp"
    rule_no    = 110
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name        = "lab-main-nacl"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# NACL Associations for Public Subnets
resource "aws_network_acl_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  network_acl_id = aws_network_acl.main.id
}

# NACL Associations for Private Subnets
resource "aws_network_acl_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  network_acl_id = aws_network_acl.main.id
}

# S3 VPC Endpoint (Gateway)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-2.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.public.id], aws_route_table.private[*].id)

  tags = {
    Name        = "lab-s3-endpoint"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# DynamoDB VPC Endpoint (Gateway)
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-2.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = concat([aws_route_table.public.id], aws_route_table.private[*].id)

  tags = {
    Name        = "lab-dynamodb-endpoint"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Security Group for ECR VPC Endpoints
resource "aws_security_group" "ecr_endpoints" {
  name        = "ecr-endpoints-sg"
  description = "Security group for ECR VPC Endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block] # Allow HTTPS from VPC
  }

  tags = {
    Name        = "ecr-endpoints-sg"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# ECR API VPC Endpoint (Interface)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-2.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.ecr_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "lab-ecr-api-endpoint"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# ECR DKR VPC Endpoint (Interface)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-2.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.ecr_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "lab-ecr-dkr-endpoint"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# S3 Bucket for VPC Flow Logs
resource "aws_s3_bucket" "flow_logs" {
  bucket        = "opentofu-flow-logs-jason4151" # Must be globally unique
  force_destroy = true                           # Automatically empty bucket on destroy

  tags = {
    Name        = "lab-flow-logs-bucket"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Lifecycle Rule for Flow Logs Bucket
resource "aws_s3_bucket_lifecycle_configuration" "flow_logs_lifecycle" {
  bucket = aws_s3_bucket.flow_logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"
    expiration {
      days = 1
    }
  }
}

# VPC Flow Logs (Rejected Traffic Only)
resource "aws_flow_log" "vpc_flow" {
  vpc_id               = aws_vpc.main.id
  traffic_type         = "REJECT" # Log only rejected traffic to reduce volume
  log_destination      = aws_s3_bucket.flow_logs.arn
  log_destination_type = "s3" # Explicitly set to S3 for Parquet support
  log_format           = "$${version} $${account-id} $${interface-id} $${srcaddr} $${dstaddr} $${srcport} $${dstport} $${protocol} $${packets} $${bytes} $${start} $${end} $${action} $${log-status}"

  destination_options {
    file_format = "parquet" # Compresses logs to reduce S3 storage costs
  }

  tags = {
    Name        = "lab-vpc-flow-logs"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}