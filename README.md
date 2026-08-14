# OpenTofu

[![Setup Environment](https://github.com/jason4151/opentofu/actions/workflows/setup-environment.yml/badge.svg)](https://github.com/jason4151/opentofu/actions/workflows/setup-environment.yml)
[![Teardown Environment](https://github.com/jason4151/opentofu/actions/workflows/teardown-environment.yml/badge.svg)](https://github.com/jason4151/opentofu/actions/workflows/teardown-environment.yml)

## Purpose

Personal AWS lab in `us-east-2`, managed with [OpenTofu](https://opentofu.org/) 1.10 and GitHub Actions (OIDC). This is a lab, not a multi-account production landing zone.

## How to fire it up

1. `remote_state/` and `iam/` are bootstrap. Apply those locally if the S3 state bucket or GitHub OIDC role do not already exist.
2. From `main`, run **Set Up AWS Environment** and type `DEPLOY`. That applies VPC, then jump box, ECR, and **EKS Auto Mode** in parallel.
3. Tear down with **Tear Down AWS Environment** and `DESTROY`.

If an old managed-node-group cluster named `lab-eks-cluster` is still in the account, destroy that stack first. Auto Mode uses the same cluster name and a different resource set.

IAM OIDC only trusts `refs/heads/main`. Run workflows from `main`.

## Structure

- **`vpc/`**: Public/private subnets, optional NAT, VPC endpoints, flow logs.
- **`iam/`**: Lab IAM user (console bootstrap) and GitHub Actions OIDC role.
- **`jump_box/`**: Private AL2023 instance with SSM.
- **`eks/`**: EKS **Auto Mode** (Kubernetes 1.34). Access entries only, no `aws-auth` ConfigMap.
- **`ecr/`**: `lab/subnet-calculator` repository.
- **`remote_state/`**: S3 state bucket and DynamoDB lock table. Apply locally once.
- **`analytics/`**: Athena/Glue over VPC flow logs. Optional; not in setup.
- **`.github/workflows/`**: Per-stack plan/apply/destroy plus setup/teardown. No apply-on-push.

## Notes

- OpenTofu `>= 1.10.0`, AWS provider `~> 5.100`. Lock files are committed.
- NAT Gateway is on by default and is the main idle cost. Set `enable_nat_gateway = false` if you do not need outbound from private subnets.
- EKS public API defaults to `0.0.0.0/0` so the lab is reachable. Override `public_endpoint_cidr` with your IP when you can.
- GitHub Actions role uses a lab policy (EC2/EKS/ECR/S3/IAM/…) rather than `AdministratorAccess`. Your `jason4151` IAM user is still admin for console/bootstrap.
