# IAM Configuration

This module manages IAM resources for the lab environment, specifically the `jason4151` IAM user with administrative privileges.

## Purpose
### Chicken or the egg
This module defines and manages the `jason4151` IAM user, which is used for deploying and managing AWS resources via OpenTofu with full `AdministratorAccess` privileges. A "chicken and egg" problem arises because `jason4151` must exist with sufficient permissions to deploy OpenTofu configs (e.g., create S3 state bucket, DynamoDB table), yet this module is intended to manage it. To resolve this, `jason4151` was initially created manually in the AWS Console with `AdministratorAccess` and access keys to bootstrap the environment. After setup, the user and its policy were imported into OpenTofu state using `tofu import` to bring it under Infrastructure-as-Code (IaC) control. Access keys are not managed here and must be created manually in the Console for security.

## Resources
- `aws_iam_user.jason4151`: The `jason4151` user with standard lab tags.
- `aws_iam_user_policy_attachment.admin_access`: Attaches `arn:aws:iam::aws:policy/AdministratorAccess` to `jason4151`.

## Prerequisites
- AWS CLI configured with existing `jason4151` credentials (access key and secret key created manually in the Console).
- OpenTofu installed locally.

## Usage
```bash
cd iam
tofu init
tofu import aws_iam_user.jason4151 jason4151
tofu import aws_iam_user_policy_attachment.admin_access jason4151/arn:aws:iam::aws:policy/AdministratorAccess
tofu apply
```