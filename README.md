# OpenTofu
[![Setup Environment](https://github.com/jason4151/opentofu/actions/workflows/setup-environment.yml/badge.svg)](https://github.com/jason4151/opentofu/actions/workflows/setup-environment.yml)
[![Teardown Environment](https://github.com/jason4151/opentofu/actions/workflows/teardown-environment.yml/badge.svg)](https://github.com/jason4151/opentofu/actions/workflows/teardown-environment.yml)

## Purpose
This repository contains Infrastructure-as-Code (IaC) configurations using [OpenTofu](https://opentofu.org/), an open-source fork of Terraform managed by the Linux Foundation. It manages AWS cloud resources for my personal lab environment. **OpenTofu maintains full compatibility with Terraform**, utilizing identical syntax, providers, and modules, while being community-driven.

- Designed for my AWS lab environment in `us-east-2`, this configuration is easily adaptable for production use with enhancements for an AWS multi-account organization.
- Currently defines AWS resources such as VPC, IAM, EC2 (jump box), EKS, ECR, S3 (state storage and flow logs), and analytics (Athena/Glue).
- Deploys infrastructure automatically or manually using GitHub Actions workflows with OIDC authentication to AWS.
- Applications are deployed to EKS using Helm Charts and GitHub Actions, with app code stored in separate repositories within my GitHub account.

## Structure
- **`vpc/`**: Defines a VPC with public/private subnets, NAT Gateway (optional), and VPC Endpoints (S3, ECR, DynamoDB).
- **`iam/`**: Configures IAM roles and OIDC provider for GitHub Actions.
- **`jump_box/`**: Provisions an EC2 instance in a private subnet for SSM access.
- **`eks/`**: Sets up an EKS cluster with Spot instances and a Classic ELB for app exposure.
- **`ecr/`**: Manages an ECR repository (`lab/*`) for app container images.
- **`s3_state_bucket/`**: Creates an S3 bucket and DynamoDB table for OpenTofu state and locking.
- **`analytics/`**: Configures Athena and Glue to analyze VPC Flow Logs.
- **`.github/workflows/`**: GitHub Actions workflows for lifecycle management.

## Architecture
(Diagram in progress)

## Future Enhancements
- Harden the jump box to CIS Amazon Linux 2023 standards using Ansible.
- Add API Gateway with CloudFront and WAF for secure, scalable app frontends.
- Implement an event-driven application using AWS Lambda and EventBridge.
- Include an architecture diagram to visualize the infrastructure.
- Expand modularity to support multi-region or multi-account setups.
- Enhance EKS with monitoring (e.g., Prometheus, Grafana).