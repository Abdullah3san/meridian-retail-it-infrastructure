# RB-01 — Ransomware on a staff PC

**Severity:** SEV-2 if contained to one workstation. **SEV-1** if a second host, a server, or `files01` data shows encryption.
**Goal:** stop the spread in minutes, recover the files from backup, never restore the PC in place.

## Signs

- Wazuh alert from the Windows Defender decoders, or a burst of file-integrity changes on one host
- Files with new extensions and a ransom note (`README`, `DECRYPT`, `HOW_TO_RECOVER`…) in folders
- A user reports files that won't open, or the Nextcloud desktop client suddenly syncing thousands of changes
- Several Nextcloud users seeing changed files in a shared folder at the same time

## First 15 minutes — contain

**Whoever is at the PC** (talk them through it by phone):

1. **Unplug the network cable, or turn WiFi off. Don't shut the PC down.** Powering off can lose evidence that's only in memory, and some ransomware does damage on reboot.
2. Don't log in anywhere else with that account. Leave a "do not use" note on the PC.

**IT:**

3. **Find the host's IP**: Wazuh agent list, or DHCP leases on the site's firewall (*Status > DHCP Leases*).
4. **Quarantine it at the firewall**: add the IP to the `QUARANTINE` alias (*Firewall > Aliases*), then apply. It loses access to everything except sending Wazuh telemetry ([rules](../configs/pfsense/firewall-rules-hq.md#floating-incident-quarantine-pre-staged-on-all-3-firewalls)).
5. **Cut it off at layer 2 too.** The firewall can't stop traffic between PCs on the same VLAN, so shut its switch port, or block the client on the AP if it's on WiFi:
   ```
   interface GigabitEthernet1/0/<port>
    shutdown
   ```
6. **Disable the user's account** on `dc01`. This also locks them out of every SSO app ([03](../docs/03-identity-and-access.md#single-sign-on-authelia)); Authelia drops existing sessions at its next LDAP refresh.
   ```bash
   samba-tool user disable <username>
   ```
7. **Stop the encrypted files syncing over the good ones.** Disabling the account in Nextcloud blocks its desktop and mobile clients straight away, even with saved app passwords:
   ```bash
   cd /opt/stacks/nextcloud
   docker compose exec -u www-data nextcloud php occ user:disable <username>
   ```

## Next hour — scope

8. **Other hosts:** in Wazuh, search all agents for the same Defender detection name, file hash, or ransom-note filename over the last 7 days. Any match: quarantine it the same way and treat the incident as **SEV-1**.
9. **Shared data:** list the Nextcloud group folders and shares the user could write to. Check those folders for encrypted files in other users' views too.
10. **The account:** in Wazuh, check where this account logged in during the last 48 hours. A logon to a server, or a privileged-group change alert, means **SEV-1**.
11. **Entry point:** usually email. Search Mailcow (Rspamd history, or the user's mailbox) for recent attachments or links, and remove the same message from every mailbox:
    ```bash
    cd /opt/mailcow-dockerized
    docker compose exec dovecot-mailcow doveadm search -A mailbox INBOX header Message-ID '<id>'
    docker compose exec dovecot-mailcow doveadm expunge -A mailbox INBOX header Message-ID '<id>'
    ```

**If it's SEV-1** (servers or multiple hosts): tell the business owner now. Call the cyber insurer's hotline before restoring anything, because many policies require their incident response firm. Consider cutting the branch tunnels (disable the WireGuard peers on `fw-hq`) so it can't cross sites. Server recovery follows the PBS restore path in [07](../docs/07-disaster-recovery.md#rto--rpo-targets).

## Recover

12. **Capture evidence first:** the ransom note, one encrypted file, the Defender detection details, and a Wazuh event export. Save them to the incident record. Image the disk only if the insurer asks.
13. **Wipe and reinstall the PC** from the standard Windows build, then domain-join it (GPO reapplies the baseline). Never "clean" an infected install.
14. **Restore the user's files** to the last nightly backup before the first encrypted file appeared:
    - **A few files:** Nextcloud's file versions (*Versions* tab), file by file.
    - **Folders or a whole user:** file-level restore of `files01` from `pbs01` (*Proxmox > files01 > Backup > File Restore*). Copy the user's directory back into the Nextcloud data volume, then rescan:
      ```bash
      docker compose exec -u www-data nextcloud php occ files:scan <username>
      ```
15. **Bring the account back clean:** reset the password, re-enrol the user's TOTP in Authelia, enable the account (`samba-tool user enable`, `occ user:enable`), and undo the switch-port shutdown and quarantine entry.

## Verify before closing

- [ ] Reinstalled PC: full Defender scan clean, Wazuh agent reporting
- [ ] No new matching detections on any agent for 72 hours
- [ ] The user and any share owners confirm their files open correctly
- [ ] Removed from the `QUARANTINE` alias; switch port back on
- [ ] Malicious email purged from every mailbox; sender/domain blocked in Rspamd

## Afterwards

- Incident record completed within 5 business days, with root cause and fixes.
- **PCI:** no card data lives on staff PCs ([ADR-0008](../docs/adr/0008-p2pe-terminals-for-pci-scope.md)), so this isn't a card incident **unless** a POS register or the POS VLAN was touched. If it was, also run [RB-02](RB-02-lost-or-tampered-pos-device.md).
- If the way in was phishing: a short refresher for the affected team, and review the Rspamd rules for whatever let it through.
