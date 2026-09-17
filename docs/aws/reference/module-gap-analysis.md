# AWS module and input gap analysis

## Available shared modules

The requested `aws-template` source path uses `modules/acr`, but that module does not exist in the AWS repository. The closest naming equivalent is `modules/ecr_repository`; it is not required for the core firewall deployment. The modules used by this composition are:

| Capability | AWS-template module | Use |
| --- | --- | --- |
| VPC, IGW, subnets, NAT, route tables | `modules/vpc` | Used |
| Security group and rules | `modules/security_group` | Used |
| EC2 trust role and instance profile | `modules/iam_role` | Used |
| Generic EC2 instance | `modules/ec2_instance` | Not used: it cannot model the required FortiGate multi-NIC topology and source/destination-check setting |

## Missing modules or AWS-specific behavior

These capabilities are not currently available in `aws-template` and are represented by inputs, native resources, or documented placeholders:

1. FortiGate AWS VM module with license/AMI selection, bootstrap, interface ordering, and HA configuration.
2. Multi-interface EC2 support with static primary private IPs and `source_dest_check = false` in the generic EC2 module.
3. FortiGate-compatible internal NLB/GWLB data-plane load balancing. The available ALB module is layer 7 and is not equivalent to Azure HA Ports/floating IP forwarding.
4. FortiGate HA heartbeat/failover orchestration and automatic route-target movement.
5. AWS Marketplace agreement and FortiGate entitlement automation.
6. A secret-management/bootstrap integration that avoids placing admin credentials or bootstrap content in Terraform state.

## Inputs still required

Before applying, provide or confirm:

- AWS account, region, and two AZs for HA.
- A real FortiGate AMI ID for the selected region and the BYOL or PAYG licensing model.
- FortiOS bootstrap/user-data, admin access method, and either an approved EC2 key pair or SSM design.
- VPC, external/internal/HA/management subnet CIDRs and the desired static private IPs.
- Approved management, workload-forwarding, and external-ingress CIDR ranges.
- The FortiGate HA heartbeat, cluster, and failover behavior.
- Whether the data plane should use GWLB, NLB, or a different AWS routing pattern.
- Workload route-table IDs and the route automation mechanism, if workload routes are enabled.
- S3 state bucket, lock table, and their security/retention requirements.
- The least-privilege IAM policy required by the chosen FortiGate failover and route-management design.

The dev and prod tfvars files contain syntactically valid placeholders so the topology can be reviewed. The AMI, backend, owner tag, CIDR approvals, bootstrap, and failover inputs must be replaced before a real apply.
