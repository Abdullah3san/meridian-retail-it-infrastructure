# pfSense VLAN Interface Assignments

Design context: [01 — Network Architecture](../../docs/01-network-architecture.md#ip-addressing-plan)

Configured under **Interfaces > Assignments > VLANs** in pfSense, one tagged sub-interface per VLAN on the LAN-side physical NIC (or LAGG if using link aggregation to the core switch).

## HQ (`fw-hq`) — parent interface `igb1` (LAN trunk to core switch)

| VLAN ID | Interface name | IPv4 | Description |
|---|---|---|---|
| 10 | `igb1.10` (`MGMT`) | 10.10.10.1/24 | Management |
| 20 | `igb1.20` (`SERVERS`) | 10.10.20.1/24 | Servers |
| 30 | `igb1.30` (`STAFF`) | 10.10.30.1/24 | Staff |
| 40 | `igb1.40` (`WHOPS`) | 10.10.40.1/24 | Warehouse/Ops |
| 50 | `igb1.50` (`VOIP`) | 10.10.50.1/24 | VoIP |
| 60 | `igb1.60` (`GUEST`) | 10.10.60.1/24 | Guest WiFi |
| 70 | `igb1.70` (`CCTV`) | 10.10.70.1/24 | CCTV/IoT |
| 99 | `igb1.99` (`NATIVE_UNUSED`) | *(no IP assigned)* | Trunk native VLAN — deliberately unconfigured, no rules, no address |

## Branch North (`fw-north`) — parent interface `igb1`

| VLAN ID | Interface name | IPv4 | Description |
|---|---|---|---|
| 10 | `igb1.10` (`MGMT`) | 10.20.10.1/24 | Management |
| 30 | `igb1.30` (`POS`) | 10.20.30.1/24 | POS/Retail |
| 40 | `igb1.40` (`STAFF`) | 10.20.40.1/24 | Staff/Back Office |
| 50 | `igb1.50` (`VOIP`) | 10.20.50.1/24 | VoIP |
| 60 | `igb1.60` (`GUEST`) | 10.20.60.1/24 | Guest WiFi |
| 70 | `igb1.70` (`CCTV`) | 10.20.70.1/24 | CCTV |

## Branch South (`fw-south`) — identical layout, `10.30.x.1/24`

Same VLAN IDs and interface names as North, subnet base `10.30.x.0/24` per [01 — Network Architecture](../../docs/01-network-architecture.md#ip-addressing-plan).

## Notes

- `igb0` on every firewall is WAN (primary ISP); a second physical/USB NIC or the built-in cellular/failover slot is configured as `WAN2` (LTE) in an interface Gateway Group for automatic failover — see [01 — Network Architecture](../../docs/01-network-architecture.md#wan-edge).
- VLAN 99 exists only as the switch trunk's native VLAN trap (see [05 — Security Architecture](../../docs/05-security-architecture.md#vlan-to-vlan-policy)) — it is intentionally left with no pfSense interface IP and no DHCP, so nothing can function on it even if a frame lands there untagged.
- DHCP server is enabled per-VLAN interface (**Services > DHCP Server**) at each site independently — see [`configs/dhcp/kea-dhcp4.conf.sample`](../dhcp/kea-dhcp4.conf.sample) for the equivalent Kea config if running DHCP off-box instead of pfSense's built-in server.
