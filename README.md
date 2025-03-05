# OpenTofu

This repository contains infrastructure-as-code (IaC) configurations using OpenTofu, an open-source alternative to Terraform. It manages cloud resources (e.g., AWS) for my lab environment. It is **fully compatible with Terraform**, leveraging the same syntax, providers, and modules, while being community-driven and free of proprietary restrictions.

## Features

- Manages resources like VPCs, EC2 instances, and S3 buckets.
- Supports Terraform-compatible configurations.
- Designed for lab use; adaptable for production with modular enhancements.

## Usage

1. Install OpenTofu (`tofu` CLI).
2. Clone this repo: `git clone <repository-url>`
3. Navigate to a project: `cd <project-directory>`
4. Initialize: `tofu init`
5. Deploy: `tofu apply`

## Notes

- Requires AWS credentials and access to `us-east-2`.
- Customize via `variables.tf` or `terraform.tfvars`.