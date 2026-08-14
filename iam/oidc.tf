# iam/oidc.tf

data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  thumbprint_list = [
    data.tls_certificate.github.certificates[0].sha1_fingerprint,
  ]

  tags = {
    Name = "GitHubActionsOIDC"
  }
}

resource "aws_iam_role" "github_actions_role" {
  name = "GitHubActionsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = [
              "repo:jason4151/opentofu:ref:refs/heads/main",
              "repo:jason4151/subnet-calculator:ref:refs/heads/main",
            ]
          }
        }
      }
    ]
  })

  tags = {
    Name = "GitHubActionsRole"
  }
}

# Broad enough for this lab's stacks, without account-wide AdministratorAccess.
resource "aws_iam_policy" "github_actions_lab" {
  name        = "GitHubActionsLabPolicy"
  description = "Permissions for OpenTofu GitHub Actions in this lab account"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LabServices"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "eks:*",
          "ecr:*",
          "s3:*",
          "dynamodb:*",
          "iam:*",
          "athena:*",
          "glue:*",
          "logs:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "ssm:*",
          "sts:GetCallerIdentity",
          "sts:AssumeRole",
          "sts:TagSession",
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:CreateGrant",
          "cloudwatch:*",
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions_lab" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.github_actions_lab.arn
}
