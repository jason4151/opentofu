# S3 State Bucket

This project creates an S3 bucket and a DynamoDB table using OpenTofu to manage remote state and state locking for OpenTofu projects. It is designed for a lab environment but includes security features suitable as a foundation for broader use.

## Purpose

This configuration is intended for a **lab environment** to store OpenTofu state files securely and manage concurrency with state locking. For a **production environment**, a more modular and scalable approach could be implemented, including:

- Modular configuration to separate bucket and locking concerns.
- Enhanced IAM policies and monitoring for access control and auditing.

## Features

- **S3 Bucket**: A secure bucket (`opentofu-state-bucket-jason4151`) for storing OpenTofu state files in `us-east-2`.
- **Versioning**: Enabled to maintain a history of state file changes.
- **Encryption**: Server-side encryption with AES256 for data at rest.
- **Public Access Block**: Ensures the bucket remains private and inaccessible to the public.
- **DynamoDB Table**: A table (`opentofu-state-lock-jason4151`) for state locking to prevent concurrent modifications.
- **Lifecycle Protection**: Prevents accidental deletion of the bucket.

## Prerequisites

- OpenTofu installed (`tofu` CLI).
- AWS CLI configured with credentials and appropriate permissions.
- Access to the `us-east-2` region.

## How to Deploy
To deploy the s3_state_bucket configuration:

```bash
cd s3_state_bucket
tofu init
tofu apply
```
