# FortiGate NIC and port mapping verification

Read-only Azure inspection on 2026-09-15 confirmed the following attachment
order on both VMs. All eight NICs have Azure IP forwarding enabled. The explicit
Terraform order preserves this live sequence; no Azure attachments were changed.

| Position | Role | A IP | A Azure MAC | B IP | B Azure MAC |
|---|---|---|---|---|---|
| 1 (primary) | External | 10.32.192.4 | 7C-ED-8D-36-01-1C | 10.32.192.6 | 7C-ED-8D-35-02-E0 |
| 2 | HA | 10.32.194.4 | 7C-ED-8D-36-01-4C | 10.32.194.5 | 7C-ED-8D-35-0B-03 |
| 3 | Internal | 10.32.193.4 | 7C-ED-8D-36-05-C4 | 10.32.193.6 | 7C-ED-8D-35-0D-D3 |
| 4 | Management | 10.32.195.4 | 7C-ED-8D-36-00-06 | 10.32.195.5 | 7C-ED-8D-35-03-F9 |

Position is **not a verified FortiOS port number**. Appliance-side mapping remains
pending because no authenticated FortiOS session was used for this check.

Before any attachment reorder:

1. Refresh the Azure VM network-interface list and NIC IP/MAC addresses; the
   snapshot above may change if NICs are replaced.
2. On each appliance through the approved private management path, inspect
   physical interface names/IPs with `get system interface physical`.
3. Inspect each actual interface using `diagnose hardware deviceinfo nic <name>`.
   Compare the permanent hardware MAC with Azure, not just an HA virtual MAC.
   See [Fortinet MAC inspection guidance](https://community.fortinet.com/fortigate-3/technical-tip-how-to-find-the-interface-s-mac-address-96896).
4. Record the confirmed port-to-role mapping for A and B. Review existing HA,
   management, routing, and policy references to those ports before any change.
5. Review a fresh Terraform plan. This preservation change should show no NIC
   sequence change. If it does, stop and reconcile drift; do not apply blindly.

The shared module validates complete, unique interface names and a primary-first
enabled order. Disabled interfaces are filtered for single-VM mode. Module callers
that omit `interface_order` retain legacy behavior for backward compatibility.
