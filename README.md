# OpenTofu

## Purpose

This repository contains Infrastructure-as-Code (IaC) configurations using OpenTofu, an open-source fork of Terraform. It currently manages AWS cloud resources for my personal lab environment. OpenTofu maintains full compatibility with Terraform, utilizing identical syntax, providers, and modules, while being community-driven and managed by the Linux Foundation.
- Designed for my AWS lab environment, this configuration is easily adaptable for production use with enhancements for an AWS multi-account organization.
- Currently defines AWS resources such as VPC, IAM, EC2, EKS, and S3.
- Deploys infrastructure automatically or manually using GitHub Actions workflows.
- Applications are deployed to EKS using Helm Charts and GitHub Actions, with the applications being stored in separate repositories within my GitHub account.




