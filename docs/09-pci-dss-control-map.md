# 09 — PCI DSS Control Map

See also: [ADR-0008 — P2PE terminals for PCI scope](adr/0008-p2pe-terminals-for-pci-scope.md), [05 — Security Architecture](05-security-architecture.md), [Incident runbooks](../runbooks/)

This maps the design to **PCI DSS v4.0.1**, requirement by requirement, and is honest about what's covered by design, what still needs a recurring process, and what's a gap. It's a design-level mapping for a portfolio project, not a QSA assessment or a completed SAQ.

## Scope in one sentence

Card data is encrypted inside processor-supplied P2PE readers and decrypted only by the processor ([ADR-0008](adr/0008-p2pe-terminals-for-pci-scope.md)), so **no Meridian-operated system stores, processes, or transmits clear-text card data**, and the business is eligible for **SAQ P2PE**.

| Component | Sees clear-text card data? | PCI scope |
|---|---|---|
| P2PE card readers (branch POS counters) | Yes, inside the tamper-resistant device only | **In scope** — physical security and inspection (Req. 9) |
| Payment processor | Yes | Processor's own scope — Meridian tracks their compliance (Req. 12.8) |
| POS registers running ERPNext POS (VLAN 30) | No — amounts, approvals, and tokens only | Out of scope under P2PE; segmented anyway |
| Branch POS VLAN, WireGuard tunnels, `erp01` | No — P2PE ciphertext passes through to the processor | Out of scope under P2PE; segmented anyway |
| Everything else (staff, servers, guest, CCTV) | No | Out of scope |
| Paper (signed receipts, chargeback paperwork) | Truncated PAN only | Handled by Req. 3 and 9.4 policies |

The scope reduction depends on the P2PE solution being used **exactly as listed**. That one dependency is why reader handling shows up repeatedly below and in [RB-02](../runbooks/RB-02-lost-or-tampered-pos-device.md).

## What SAQ P2PE actually requires, and where it's met

SAQ P2PE's questions fall under Requirements 3, 9, and 12. These are the controls Meridian has to evidence every year.

| Req. | What it asks | How Meridian meets it | Status |
|---|---|---|---|
| **3.1, 3.2.1** | Don't keep card data you don't need; have a retention policy for any you do | No system stores card data. Paper receipts carry truncated PANs only. The AUP forbids writing card numbers down or storing them anywhere ([`acceptable-use-policy.md`](../policies/acceptable-use-policy.md)) | ✅ Designed |
| **9.4** | Physically secure and securely destroy media containing card data | Chargeback/dispute paperwork kept in the locked back-office safe at each branch, cross-cut shredded after the dispute window closes | 🟡 Process — store manager |
| **9.5.1.1** | Keep a current list of every card-reading device: make, model, serial, location | A "Payment devices" sheet in ERPNext's asset register, one row per reader, reconciled against the processor's device list quarterly | 🟡 Process — IT |
| **9.5.1.2** | Inspect devices for tampering or substitution, at a frequency set by risk analysis | Opening-checklist inspection at each branch (serial matches the sticker and the register, seals intact, no overlays or extra cables). Frequency set by the targeted risk analysis in 12.3.1, starting daily | 🟡 Process — store manager |
| **9.5.1.3** | Train staff to spot tampering and challenge "technicians" | Part of POS onboarding; anyone claiming to service a reader is verified with IT before touching it. Response steps in [RB-02](../runbooks/RB-02-lost-or-tampered-pos-device.md) | 🟡 Process — HR + IT |
| **12.8.1–12.8.5** | Track service providers that affect card security: written agreements, annual compliance checks, who's responsible for what | The processor is the only one. Its P2PE listing and Attestation of Compliance are checked every year and filed in BookStack, alongside a responsibility matrix from the contract | 🟡 Process — owner + IT |
| **12.10.1** | Have an incident response plan and be ready to use it | [`runbooks/`](../runbooks/), especially RB-02 (suspected skimmer or missing reader), with the processor's incident contact | ✅ Designed, 🟡 tested annually |

## Defence in depth: the full 12 requirements

Under SAQ P2PE most of PCI DSS isn't formally required, but this design meets much of it anyway, so the segmentation is a real second layer and not decoration. This table is also the starting point if P2PE is ever dropped (see below).

| Req. | Topic | Design control | Where | Status |
|---|---|---|---|---|
| 1 | Network security controls | Default-deny between VLANs. The POS VLAN reaches only the ERP POS API and the processor's endpoints. No "any → any" rule exists | [`firewall-rules-hq.md`](../configs/pfsense/firewall-rules-hq.md), [05](05-security-architecture.md#vlan-to-vlan-policy) | ✅ Designed; 🟡 rule review every 6 months (1.2.7) |
| 2 | Secure configurations | Hardened baseline on every server, CIS-informed GPO for workstations. Vendor default passwords replaced (e.g. Wazuh demo users) | [`iac/ansible`](../iac/ansible/), [`wazuh/`](../configs/docker-compose/wazuh/) | ✅ Designed |
| 3 | Protect stored account data | Nothing stored — P2PE | ADR-0008 | ✅ N/A by design |
| 4 | Encrypt card data in transit over public networks | P2PE encryption in the reader, plus TLS to the processor. POS → ERP rides WireGuard | [ADR-0002](adr/0002-wireguard-over-ipsec.md) | ✅ Designed |
| 5 | Anti-malware | Defender on workstations, ClamAV on Linux and mail, Rspamd phishing filtering | [05](05-security-architecture.md#endpoint-security) | ✅ Designed |
| 6 | Secure systems and software | Unattended security upgrades on servers; patch rings with critical patches immediately on workstations (6.3.3 needs critical patches within a month) | [02](02-server-infrastructure.md#patch-management), [05](05-security-architecture.md#patching--hardening) | ✅ Designed |
| 7 | Least-privilege access | Role-based AD groups; the POS group can reach the POS app only | [03](03-identity-and-access.md) | ✅ Designed |
| 8 | Identify and authenticate users | Unique accounts, 14-character minimum (8.3.6 needs 12), lockout after 10 failures for 30 minutes (8.3.4), MFA for admins and remote access, same-day leaver disable | [`password-policy.md`](../policies/password-policy.md) | ✅ Designed |
| 9 | Physical access | Locked server room. Reader controls as in the SAQ P2PE table above | [02](02-server-infrastructure.md#physical-layer) | ✅ / 🟡 Process |
| 10 | Logging and monitoring | Wazuh collects server, workstation, and firewall logs; time synced from the DCs (10.6) | [05](05-security-architecture.md#siem--edr-wazuh) | 🟡 Set indexer retention to 12 months, with 3 months searchable (10.5.1) |
| 11 | Test security regularly | Suricata IDS/IPS at every site (11.5.1), Wazuh file-integrity monitoring (11.5.2) | [05](05-security-architecture.md#perimeter) | ✅ Partly — scanning and pen testing are gaps (below) |
| 12 | Policies and programme | AUP, password, and backup policies; incident runbooks | [`policies/`](../policies/), [`runbooks/`](../runbooks/) | 🟡 Security awareness training (12.6) and risk analyses (12.3.1) not yet written |

## If P2PE is ever dropped

If the processor's solution loses its listing, or integrated readers are introduced, the POS path comes into scope (SAQ B-IP or worse) and these become mandatory:

| Gap | Requirement | Likely approach |
|---|---|---|
| Quarterly external scans by an Approved Scanning Vendor | 11.3.2 | Commercial ASV service against each site's public IP |
| Quarterly internal vulnerability scans | 11.3.1 | Greenbone/OpenVAS VM on VLAN 20, scanning the POS VLANs over the VPN |
| Annual segmentation penetration test | 11.4.5 | External tester proving the POS VLAN can't reach or be reached from other VLANs |
| MFA for all access into the CDE | 8.4.2 | Extend Authelia MFA to the POS application |
| Password rotation or dynamic analysis for single-factor accounts | 8.3.9 | Moot if 8.4.2 MFA is in place for POS access |
| Dedicated payment VLAN, separate from the registers | 1.3 | Split VLAN 30 into register and reader VLANs |
| Daily log review | 10.4.1 | Wazuh alerting covers automated review; document who acknowledges alerts |

## Compliance calendar

| When | Task | Owner | Requirement |
|---|---|---|---|
| Every store opening | Inspect each reader against the checklist | Store manager | 9.5.1.2 |
| Quarterly | Reconcile the reader inventory against the processor's device list | IT | 9.5.1.1 |
| Every 6 months | Review all firewall rules, removing any without a documented reason | IT | 1.2.7 |
| Annually | Get the processor's AOC and P2PE listing; complete SAQ P2PE; sign the Attestation | Owner + IT | 12.8.4, 12.4 |
| Annually | Tabletop test of RB-02 and the ransomware runbook | IT + store managers | 12.10.2 |
| Onboarding, then annually | POS device-tampering awareness | HR + IT | 9.5.1.3, 12.6 |
