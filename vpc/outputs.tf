# Output the VPC ID for use in other configurations
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

# Output the public subnet IDs as a list
output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

# Output the private subnet IDs as a list
output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

# Output the public route table ID (useful for adding custom routes)
output "public_route_table_id" {
  description = "ID of the public route table"
  value       = aws_route_table.public.id
}

# Output the private route table IDs as a list (single or HA NAT)
output "private_route_table_ids" {
  description = "List of private route table IDs"
  value       = aws_route_table.private[*].id
}

# Output the Internet Gateway ID
output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.igw.id
}

# Output the NAT Gateway IDs as a list (single or HA)
output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.nat[*].id
}

# Output the S3 VPC Endpoint ID (for policy attachments if needed)
output "s3_vpc_endpoint_id" {
  description = "ID of the S3 VPC Endpoint"
  value       = aws_vpc_endpoint.s3.id
}

# Output the DynamoDB VPC Endpoint ID
output "dynamodb_vpc_endpoint_id" {
  description = "ID of the DynamoDB VPC Endpoint"
  value       = aws_vpc_endpoint.dynamodb.id
}

# Output the ECR VPC Endpoint ID
output "ecr_vpc_endpoint_id" {
  description = "ID of the ECR VPC Endpoint"
  value       = aws_vpc_endpoint.ecr.id
}