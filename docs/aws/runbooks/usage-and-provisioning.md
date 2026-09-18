# AWS usage and provisioning runbook

## Working directory

Run Terraform from the repository root. The AWS root is `platforms/aws`, and the environment-specific inputs are under `platforms/aws/environments`.

## Prerequisites

- Terraform 1.6 or newer.
- AWS credentials with permission to create the VPC, ENIs, EC2 instances, IAM role/profile, security group, NAT gateways, and any requested routes.
- An S3 state bucket and DynamoDB lock table. Replace the placeholders in the selected `backend.hcl` first.
- A real FortiGate AMI ID for `aws_region`. The checked-in `ami-00000000000000000` value is only a plan-review placeholder.
- Approved FortiOS CLI bootstrap content supplied as a protected `TF_VAR_fortigate_bootstrap_config` value or equivalent secret pipeline input.

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

The two examples select the mode through `fortigate_deployment_mode`: `single` creates one node with external/internal interfaces; `ha` creates nodes `a` and `b` with external, HA, internal, and management interfaces in separate AZs. The HA prod example also enables the Gateway Load Balancer module and registers each node's internal traffic-interface IP as a GENEVE target.

## Required substitutions before apply

Replace the backend bucket and lock-table names, `fortigate_ami_id`, owner tag, management/workload CIDRs, and FortiOS bootstrap. Review instance type, static IPs, licensing, IAM permissions, GWLB endpoint placement, route-table steering, and FortiOS GENEVE/health-check configuration against the selected FortiGate release.

The FortiGate module disables source/destination checks on every FortiGate ENI. GWLB is provisioned only when `enable_internal_load_balancer` is true; it does not create GWLB endpoints or route-table steering. Workload routes are disabled by default; enabling them invokes `route_manager` and requires approved route table IDs. With ENI targets, the root defaults to node `a` internal as primary and node `b` internal as secondary in HA. The `active_target` switch is declarative and is not a runtime health monitor.

## Verification

After apply, inspect the outputs for `fortigate_instance_ids`, `fortigate_interface_ids`, `fortigate_private_ips`, `gateway_load_balancer_arn`, and `implementation_gaps`. Confirm the FortiOS cluster forms, the intended node is active, GWLB targets become healthy, management access is restricted, and the selected AWS routing design passes traffic before enabling workload routes.
