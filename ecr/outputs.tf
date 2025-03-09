# ecr/outputs.tf

output "subnet_calculator_repository_url" {
  description = "URL of the subnet-calculator ECR repository"
  value       = aws_ecr_repository.subnet_calculator.repository_url
}

output "subnet_calculator_repository_arn" {
  description = "ARN of the subnet-calculator ECR repository"
  value       = aws_ecr_repository.subnet_calculator.arn
}