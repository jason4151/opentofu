# EC2 Jump Box

This project deploys an EC2 instance jump box in an AWS environment using OpenTofu. It integrates with an existing VPC created separately (e.g., from the `vpc` project). The jump box uses AWS Systems Manager (SSM) Session Manager for secure access, avoiding the need for SSH key management.

## Purpose

This configuration is intended for a **lab environment**. It provides a lightweight, cost-effective jump box for testing and accessing resources within a VPC. For a **production environment**, a more robust setup would be required, including:

- Modular configuration for reusability and separation of concerns.
- High availability (HA) with multiple instances across Availability Zones or regions.
- Enhanced security measures, such as private subnet placement with VPC endpoints for SSM and stricter security group rules.

## Features

- **EC2 Instance**: A `t3.nano` instance running Amazon Linux 2023, placed in a public subnet.
- **IAM Role**: Grants SSM Session Manager access via the `AmazonSSMManagedInstanceCore` policy.
- **Security Group**: Allows outbound HTTPS (for SSM) and all traffic within the VPC CIDR; no inbound rules for simplicity.
- **Integration**: References VPC details (e.g., VPC ID, subnet IDs) from a remote state stored in S3.
- **Cost Efficiency**: Uses a public IP to avoid NAT gateway or additional VPC endpoint costs in a lab setting.

## Prerequisites

- OpenTofu installed (`tofu` CLI).
- AWS CLI configured with credentials and appropriate permissions.
- An existing VPC deployed (e.g., from the `vpc` project) with its state stored in an S3 bucket (`opentofu-state-bucket-jason4151`).
- Access to the `us-east-2` region.

## How to Deploy
To deploy the ec2_jump_box configuration:

```bash
cd ec2_jump_box
tofu init
tofu apply
```