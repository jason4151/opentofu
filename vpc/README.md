# VPC

This project defines an AWS VPC configuration using OpenTofu, designed specifically for a lab environment. It creates a basic VPC setup with public and private subnets, an internet gateway, optional NAT gateways, VPC gateway endpoints (free), and flow logs, all within the `us-east-2` region.

## Purpose

This configuration is intended for a **lab environment**. It provides a simple, single-region VPC setup suitable for testing and experimentation. For a **production environment**, a more robust and modular configuration would be required, including:

- Modular design for reusability and maintainability.
- High availability (HA) across multiple AWS regions.
- Enhanced security and scalability features, such as separate route tables per subnet, fine-grained NACLs, and HA NAT gateways by default.

## Features

- **VPC**: A /22 CIDR block (1,024 IPs) with DNS support and hostnames enabled.
- **Subnets**: 2 public and 2 private /26 subnets (64 IPs each) across 2 Availability Zones in `us-east-2`.
- **Internet Gateway**: Enables internet access for public subnets.
- **NAT Gateway**: Optional, with support for high availability (HA) across AZs if enabled.
- **Security**: Default security group denies all traffic; custom NACL allows HTTP/HTTPS traffic.
- **VPC Endpoints**: Gateway endpoints for S3 and DynamoDB to keep traffic internal.
- **Flow Logs**: Logs rejected traffic to an S3 bucket with Parquet compression and a 1-day expiration for cost efficiency.

## Prerequisites

- OpenTofu installed (`tofu` CLI).
- AWS CLI configured with credentials and appropriate permissions.
- An AWS account with access to the `us-east-2` region.

## How to Deploy
To deploy the VPC configuration:

```bash
cd vpc
tofu init
tofu apply
```