# Define the VPC with a configurable /22 CIDR (1,024 IPs)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true # Needed for VPC endpoints and DNS resolution
  enable_dns_hostnames = true # Ensures proper DNS for private hosted zones and endpoints

  tags = {
    Name        = "lab-vpc"
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
    Name        = "lab-default-sg"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Manage the default route table to prevent unused artifacts
resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  # No routes defined - ensures it remains unused and clean
  tags = {
    Name        = "lab-default-rt"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Manage the default NACL to prevent unused artifacts
resource "aws_default_network_acl" "default" {
  default_network_acl_id = aws_vpc.main.default_network_acl_id

  # No rules defined - ensures it remains unused since custom NACL is applied
  tags = {
    Name        = "lab-default-nacl"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Define a custom DHCP Option Set with AWS DNS and NTP
resource "aws_vpc_dhcp_options" "default" {
  domain_name_servers = ["AmazonProvidedDNS"] # AWS-provided DNS servers
  ntp_servers         = ["169.254.169.123"]   # Amazon Time Sync Service

  tags = {
    Name        = "lab-default-dhcp"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Associate the custom DHCP Option Set with the VPC
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
    Project     = "core-infra"
  }
}

# Fetch 2 Availability Zones in us-east-2
data "aws_availability_zones" "available" {
  state = "available"
}

# Public Subnets (2 x /26 across 2 AZs)
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 4, count.index) # /26 (64 IPs)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "lab-public-subnet-${count.index}"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Private Subnets (2 x /26 across 2 AZs)
resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr_block, 4, count.index + 2) # Offset by 2, still /26
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name        = "lab-private-subnet-${count.index}"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Elastic IP for NAT Gateway (only created if enabled)
resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? (var.ha_nat_gateways ? 2 : 1) : 0

  tags = {
    Name        = "lab-nat-eip-${count.index}"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# NAT Gateway(s) for private subnets (only created if enabled)
resource "aws_nat_gateway" "nat" {
  count = var.enable_nat_gateway ? (var.ha_nat_gateways ? 2 : 1) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = var.ha_nat_gateways ? aws_subnet.public[count.index].id : aws_subnet.public[0].id

  tags = {
    Name        = "lab-nat-gateway-${count.index}"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Route Table for Public Subnets (single table)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "lab-public-rt-0"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Associate public subnets with the public route table
resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Route Table for Private Subnets (single table unless HA NAT enabled)
resource "aws_route_table" "private" {
  count = var.enable_nat_gateway && var.ha_nat_gateways ? 2 : 1

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
    Project     = "core-infra"
  }
}

# Associate private subnets with their route tables
resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.enable_nat_gateway && var.ha_nat_gateways ? aws_route_table.private[count.index].id : aws_route_table.private[0].id
}

# Network ACL with rules adjusted for public web traffic
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
    Project     = "core-infra"
  }
}

# Associate NACL with all subnets
resource "aws_network_acl_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  network_acl_id = aws_network_acl.main.id
}

resource "aws_network_acl_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  network_acl_id = aws_network_acl.main.id
}

# VPC Endpoint for S3 (Gateway, free, keeps traffic internal)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-2.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat([aws_route_table.public.id], aws_route_table.private[*].id)

  tags = {
    Name        = "lab-s3-endpoint"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# VPC Endpoint for DynamoDB (Gateway, free, keeps traffic internal)
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-2.dynamodb"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat([aws_route_table.public.id], aws_route_table.private[*].id)

  tags = {
    Name        = "lab-dynamodb-endpoint"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# S3 bucket for VPC Flow Logs with cost-effective storage
resource "aws_s3_bucket" "flow_logs" {
  bucket        = "opentofu-flow-logs-jason4151" # Must be globally unique
  force_destroy = true                           # Automatically empty bucket on destroy

  tags = {
    Name        = "lab-flow-logs-bucket"
    Environment = "lab"
    Project     = "core-infra"
  }
}

# Lifecycle rule to expire logs after 1 day for cost savings in lab
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

# VPC Flow Logs to S3 with Parquet compression, logging only rejected traffic
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
    Project     = "core-infra"
  }
}