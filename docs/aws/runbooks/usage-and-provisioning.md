# AWS usage and provisioning runbook

## Working directory

Run Terraform from the repository root. The AWS root is `platforms/aws`, and the environment-specific inputs are under `platforms/aws/environments`.

## Prerequisites

- Terraform 1.6 or newer.
- AWS credentials with permission to create the VPC, ENIs, EC2 instances, IAM role/profile, security group, NAT gateways, and any requested routes.
- An S3 state bucket and DynamoDB lock table. Replace the placeholders in the selected `backend.hcl` first.
- A real FortiGate AMI ID for `aws_region`. The checked-in `ami-00000000000000000` value is only a plan-review placeholder.
- Approved FortiOS bootstrap content supplied as a protected `TF_VAR_fortigate_user_data` value or equivalent secret pipeline input.

## Initialize, plan, and apply

For simple dev mode:

```powershell
terraform -chdir=platforms/aws init -backend-config=environments/dev/backend.hcl
terraform -chdir=platforms/aws plan -var-file=environments/dev/terraform.tfvars -out=tfplan
terraform -chdir=platforms/aws apply tfplan
```

For HA prod mode:

```powershell
terraform -chdir=platforms/aws init -backend-config=environments/prod/backend.hcl
terraform -chdir=platforms/aws plan -var-file=environments/prod/terraform.tfvars -out=tfplan
terraform -chdir=platforms/aws apply tfplan
```

The two examples select the mode through `fortigate_deployment_mode`: `single` creates one node with external/internal interfaces; `ha` creates nodes `a` and `b` with external, HA, internal, and management interfaces in separate AZs.

## Required substitutions before apply

Replace the backend bucket and lock-table names, `fortigate_ami_id`, owner tag, management/workload CIDRs, and FortiOS bootstrap. Review instance type, interface limits, static IPs, licensing, and IAM permissions against the selected FortiGate release.

The composition disables source/destination checks on every FortiGate ENI. Workload routes are disabled by default because AWS route targets cannot use the Azure-style internal load-balancer frontend. Enabling them requires approved route table IDs and a reachable FortiGate ENI ID; in HA mode, automatic active-node route movement is still a placeholder.

## Verification

After apply, inspect the outputs for `fortigate_instance_ids`, `fortigate_interface_ids`, `fortigate_private_ips`, and `implementation_gaps`. Confirm the FortiOS cluster forms, the intended node is active, management access is restricted, and the selected AWS routing/load-balancing design passes traffic before enabling workload routes.
