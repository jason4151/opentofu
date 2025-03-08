# vpc/outputs.tf

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "account_id" {
  description = "AWS Account ID"
  value       = data.aws_caller_identity.current.account_id
}

output "ecr_api_endpoint_id" {
  description = "ID of the ECR API VPC Endpoint"
  value       = aws_vpc_endpoint.ecr_api.id
}

output "ecr_dkr_endpoint_id" {
  description = "ID of the ECR DKR VPC Endpoint"
  value       = aws_vpc_endpoint.ecr_dkr.id
}

output "s3_endpoint_id" {
  description = "ID of the S3 VPC Endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "dynamodb_endpoint_id" {
  description = "ID of the DynamoDB VPC Endpoint"
  value       = aws_vpc_endpoint.dynamodb.id
}