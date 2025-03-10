# ecr/main.tf

# ECR Repository for subnet-calculator
resource "aws_ecr_repository" "subnet_calculator" {
  name                 = "lab/subnet-calculator"  # Namespaced under lab/
  image_tag_mutability = "MUTABLE"                # Allows overwriting tags

  # AES-256 encryption for images
  encryption_configuration {
    encryption_type = "AES256"
  }

  # Enable image scanning on push for security
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "lab-subnet-calculator"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Lifecycle Policy to manage untagged images
resource "aws_ecr_lifecycle_policy" "subnet_calculator_policy" {
  repository = aws_ecr_repository.subnet_calculator.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the last 10 untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "imageCountMoreThan"
          countNumber = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}