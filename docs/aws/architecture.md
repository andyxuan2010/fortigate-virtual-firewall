# AWS FortiGate implementation

The AWS composition in `platforms/aws` mirrors the Azure root's two deployment modes:

| Mode | Nodes | Interfaces per node | Availability zones |
| --- | ---: | --- | --- |
| `single` | 1 | external, internal | first configured AZ |
| `ha` | 2 | external, HA, internal, management | first and second configured AZs |

The VPC, subnet, security-group, and IAM-role foundations use the public modules from [aws-template](https://github.com/andyxuan2010/aws-template):

- `modules/vpc`
- `modules/security_group`
- `modules/iam_role`

FortiGate interfaces are native `aws_network_interface` resources so the composition can set static private IPs and `source_dest_check = false`. Native `aws_instance` resources are used because the shared `ec2_instance` module currently exposes only one primary interface and does not expose the FortiGate-specific networking controls required here.

Simple mode creates one external and one internal subnet/ENI. HA mode creates external, HA, internal, and management subnets/ENIs for nodes `a` and `b`, with the two nodes placed in separate AZs. The HA heartbeat/bootstrap configuration is supplied through `fortigate_user_data` and is intentionally not fabricated by this repository.

The implementation is a provisioning scaffold, not yet a complete FortiGate service integration. AWS does not have an equivalent of Azure's internal load balancer with HA Ports/floating IP in the available template modules. The optional load-balancer and workload-route settings therefore remain explicit placeholders until an AWS NLB/GWLB and route-failover design is selected.
