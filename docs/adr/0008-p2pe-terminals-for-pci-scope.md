# ADR-0008: Card payments via processor-supplied P2PE terminals, keeping the network out of PCI scope

**Status:** Accepted
**Affects:** [09 — PCI DSS Control Map](../09-pci-dss-control-map.md), [05 — Security Architecture](../05-security-architecture.md#vlan-to-vlan-policy), [04 — Software Stack](../04-software-stack.md#whats-deliberately-not-self-hosted), [`firewall-rules-hq.md`](../../configs/pfsense/firewall-rules-hq.md#branch-pos-vlan-30--fw-north--fw-south)

## Context

The branches take card payments. How the card reader connects decides how much of Meridian's network a PCI DSS assessment covers, and therefore how much compliance work one IT generalist has to carry every year. Three realistic options:

1. **Integrated card readers wired into the POS software.** Card data passes through the POS register and ERPNext. The register, the POS VLAN, the VPN, `erp01`, and anything that can reach them become the cardholder data environment (CDE). Full SAQ D scope.
2. **Standalone IP-connected readers that aren't P2PE-validated** (SAQ B-IP). Card data never touches ERPNext, but the network carrying it is in scope: segmentation testing, quarterly vulnerability scans, and most of requirements 1, 2, 6, 8, 10, and 11 apply to the POS segment.
3. **Readers from a PCI-listed point-to-point encryption (P2PE) solution**, supplied and managed by the payment processor. Card data is encrypted inside the tamper-resistant reader and can only be decrypted by the processor. ERPNext sends the processor an amount, the processor drives the reader, and ERPNext gets back an approved/declined result and a token.

## Decision

**Option 3.** Every card reader is a device from the processor's PCI-listed P2PE solution, set up for server-driven integration with ERPNext. Meridian never handles clear-text card data on any system it operates.

The design changes to support it:

- The branch POS VLAN gains exactly one more egress: **TCP 443 to the processor's published endpoints** (a pfSense FQDN alias), alongside the existing ERP POS API over the VPN. Nothing else, including no general internet.
- `erp01`'s outbound allow-list gains the processor's API endpoint, so ERPNext can start and confirm payments.

## Rationale

- **It shrinks the assessment to what one person can actually maintain.** A merchant using a listed P2PE solution correctly qualifies for **SAQ P2PE**, which covers a small set of requirements: protecting any paper records, controlling and inspecting the payment devices, incident response, and managing the processor relationship. With option 2, Meridian would own quarterly scans, annual segmentation testing, and hardening evidence for the whole POS path.
- **The segmentation already built becomes defence in depth, not the only control.** With P2PE, a compromised register or VLAN still only ever sees ciphertext. The POS VLAN isolation in [05](../05-security-architecture.md#vlan-to-vlan-policy) keeps the registers and readers away from staff, guest, and IoT traffic on top of that.
- **It matches the existing "don't self-host payments" decision** in [04](../04-software-stack.md#whats-deliberately-not-self-hosted). P2PE is what makes that decision hold up under assessment, rather than just being a sentence in a design doc.

## Consequences

- **Processor lock-in for card acceptance.** The readers, their firmware, and the P2PE validation belong to the processor. Switching processors means swapping every reader and redoing the ERPNext integration.
- **Card payments need two paths up at once:** the branch's internet (reader → processor) and `erp01` (ERPNext starts each payment server-side, over the VPN). A branch on LTE failover can still take cards. A branch with no WAN, or any branch while HQ is unreachable, can't, unless the processor's readers support an offline (store-and-forward) mode, at the merchant's own risk. What to do in each case is in [RB-03](../../runbooks/RB-03-isp-failure.md).
- **Device control becomes Meridian's job** (PCI DSS Requirement 9.5): an inventory of every reader by serial number, periodic tamper inspection, and staff training to spot substitution. That process lives in [09](../09-pci-dss-control-map.md#what-saq-p2pe-actually-requires-and-where-its-met) and [RB-02](../../runbooks/RB-02-lost-or-tampered-pos-device.md).
- **The scope reduction only holds if P2PE is used exactly as listed.** Plugging a reader into a register by USB, or using a reader model that's not in the listed solution, quietly puts the network back into scope. This is why the AUP already forbids connecting devices to POS terminals ([`acceptable-use-policy.md`](../../policies/acceptable-use-policy.md)).

## Revisit if

The processor's solution loses its P2PE listing, or the business wants features only an integrated reader provides. Either way, the POS segment would need to be assessed as option 2: a dedicated payment VLAN, quarterly ASV and internal scans, and annual segmentation testing. The gap list in [09](../09-pci-dss-control-map.md#if-p2pe-is-ever-dropped) is the starting point.
