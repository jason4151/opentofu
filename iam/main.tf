# iam/main.tf

# IAM User for jason4151
resource "aws_iam_user" "jason4151" {
  name = "jason4151"

  tags = {
    Name        = "jason4151"
    Environment = "lab"
    Owner       = "jason4151"
    Project     = "core-infra"
    CostCenter  = "lab"
  }
}

# Grant AdministratorAccess Policy
resource "aws_iam_user_policy_attachment" "admin_access" {
  user       = aws_iam_user.jason4151.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}