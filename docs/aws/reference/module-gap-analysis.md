# AWS module and input gap analysis

## Available shared modules

The requested `aws-template` source path uses `modules/acr`, but that module does not exist in the AWS repository. The closest naming equivalent is `modules/ecr_repository`; it is not required for the core firewall deployment. The modules used by this composition are:

| Capability | AWS-template module | Use |
| --- | --- | --- |
| VPC, IGW, subnets, NAT, route tables | `modules/vpc` | Used |
| Security group and rules | `modules/security_group` | Used |
| EC2 trust role and instance profile | `modules/iam_role` | Used |
| FortiGate VM, multi-ENI, bootstrap, and active-passive HA | `modules/fortigate` | Used |
| Gateway Load Balancer and GENEVE target registration | `modules/gateway_load_balancer` | Used when enabled; HA prod enables it |
| Generic EC2 instance | `modules/ec2_instance` | Not used: the FortiGate module now provides the required topology |

## Missing modules or AWS-specific behavior

These capabilities are not currently available in `aws-template` and are represented by inputs or documented placeholders:

1. GWLB endpoint, endpoint-service, and route-table composition for the approved traffic path.
2. Automatic HA route-target movement or a route-manager integration. The local `route_manager` directory is not yet committed to the public `main` branch, so it is not referenced by the root.
3. AWS Marketplace agreement and FortiGate entitlement automation.
4. A secret-management workflow that avoids placing sensitive bootstrap or BYOL license content in Terraform state.
5. FortiOS operational policy configuration, GENEVE interface behavior, and production HA validation.

## Inputs still required

Before applying, provide or confirm:

- AWS account, region, and two AZs for HA.
- A real FortiGate AMI ID for the selected region and the BYOL or PAYG licensing model.
- FortiOS bootstrap/user-data, admin access method, and either an approved EC2 key pair or SSM design.
- VPC, external/internal/HA/management subnet CIDRs and the desired static private IPs.
- Approved management, workload-forwarding, and external-ingress CIDR ranges.
- The FortiGate HA heartbeat, cluster, and failover behavior.
- FortiOS GENEVE interface and health-check configuration for GWLB.
- GWLB endpoint placement, endpoint service ownership, and route-table steering.
- Workload route-table IDs and the route automation mechanism, if workload routes are enabled.
- S3 state bucket, lock table, and their security/retention requirements.
- The least-privilege IAM policy required by the chosen FortiGate failover and route-management design.

The dev and prod tfvars files contain syntactically valid placeholders so the topology can be reviewed. The AMI, backend, owner tag, CIDR approvals, bootstrap, GWLB endpoint/routing, and failover inputs must be replaced or approved before a real apply.
