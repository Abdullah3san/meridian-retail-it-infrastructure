# RB-02 — Lost, stolen, or tampered POS device

**Severity:** **SEV-1** for any sign of tampering or substitution. SEV-2 for a reader or register that's simply missing.
**Goal:** stop the device being used, get the processor involved straight away, and preserve evidence. P2PE protects card data inside a genuine reader ([ADR-0008](../docs/adr/0008-p2pe-terminals-for-pci-scope.md)). It doesn't stop a skimmer overlay that reads the card **before** it reaches the reader, so tampering is always treated as a possible card-data compromise.

Two kinds of device sit on the branch POS VLAN:

| Device | What losing it risks |
|---|---|
| **Card reader** (processor-supplied P2PE device) | Tampering, or a swapped-in fake reader capturing cards and PINs |
| **POS register** (tablet/PC running ERPNext POS) | Misuse of the POS login: fraudulent refunds, voids, cash discrepancies |

## Signs

- The opening inspection fails: serial doesn't match the sticker or the inventory, broken or replaced seals, an overlay on the card slot or keypad, extra cables, a loose or extra-thick bezel
- A reader or register is missing
- Someone turns up to "service" or "replace" a reader without IT having arranged it
- A processor alert: device offline unexpectedly, moved, or showing unusual transactions
- Customers report fraud after shopping at one branch

## First 15 minutes — stop and secure (store manager)

1. **Stop using the device.** Move that counter to another reader that **passed today's inspection**, or to cash only.
2. **If it may have been tampered with: don't unplug it, open it, or clean it.** Leave it where it is, put a "do not use" note on it, and handle it as little as possible. It's evidence.
3. **If someone is there claiming to be a technician:** don't let them touch anything. Ask for ID and a job reference, then call IT to verify. Genuine visits are always arranged by IT in advance.
4. **Call IT.** Note the time, when the device last passed inspection, and who had access since then.

## Next hour — IT

5. **Call the processor's fraud/support line** (number on the contact sheet). Report the device's serial number as lost, stolen, or suspected tampered, so they deactivate it and it can't process payments. Write down the reference number. **From here on, follow the processor's instructions and their P2PE Instruction Manual (PIM)**: they decide whether forensics are needed and what happens to the device.
6. **Check every other reader**, at this branch and the other one, using the inspection checklist. Substitution attacks usually hit more than one device. Mark anything doubtful as suspect too.
7. **Look for a swapped-in device on the network.** Compare the branch firewall's DHCP leases for VLAN 30 (*Status > DHCP Leases*) with the MAC addresses in the device inventory. Shut the switch port of anything that isn't in the inventory.
8. **If a register is missing:** disable the POS user(s) signed in on it and change any POS profile PINs in ERPNext. If it's domain-joined, disable its computer account in AD.
9. **Update the inventory**: mark the device's status as lost or suspect in ERPNext's asset register (PCI DSS 9.5.1.1).
10. **Pull CCTV footage** from the branch NVR for the window between the last good inspection and now, before it's overwritten.
11. **Theft:** the store manager files a police report. Add the report number to the incident record.

**If card data may have been captured** (an overlay found, a swapped reader, or the processor reports fraud): this is **SEV-1**. Tell the business owner now. The processor and acquirer lead from here, and may require a PCI Forensic Investigator (PFI). **Don't investigate the device yourself, and don't contact customers.** Notifications go through the acquirer and the owner.

## Recover

12. **Get replacements only from the processor**, by their tracked shipment. Never use a reader from anywhere else, even "the same model".
13. **On arrival:** check the serial number against the processor's shipping notice, inspect the device, and add it to the inventory before it's plugged in.
14. **Pair it** to the POS register through the processor's normal setup, then run a small test transaction.

## Verify before closing

- [ ] Processor confirms the old device is deactivated (reference number recorded)
- [ ] Every reader at both branches inspected and logged
- [ ] Device inventory matches the processor's device list
- [ ] Nothing on VLAN 30 that isn't in the inventory
- [ ] Replacement inspected, inventoried, and passed a test transaction

## Afterwards

- Incident record completed, including the processor's reference and any police report number.
- Refresher on device inspection for that branch's staff (PCI DSS 9.5.1.3).
- Revisit how often devices are inspected (the 9.5.1.2.1 targeted risk analysis): a tamper attempt is a reason to inspect more often for a while.
