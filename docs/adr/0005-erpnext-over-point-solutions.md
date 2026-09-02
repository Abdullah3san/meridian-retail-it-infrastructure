# ADR-0005: Business systems — ERPNext over point-solution SaaS

**Status:** Accepted
**Affects:** [04 — Software Stack](../04-software-stack.md#erpnext--the-core-of-the-business), [08 — Cost & BOM](../08-cost-and-bom.md)

## Context

The business needs accounting, inventory, POS, HR, and CRM. The realistic options: **best-of-breed point solutions** (e.g. QuickBooks + Square + a standalone CRM + a separate HR tool), or a **single ERP** covering all of it — with ERPNext as the credible open-source option (Odoo Community is the other serious contender, with a similar trade-off profile).

## Decision

Use **ERPNext** as one system for accounting, inventory, POS, HR, and CRM.

## Rationale

- **Integration is the actual product here.** A sale at Branch North should hit inventory and the books instantly, with zero nightly-sync jobs or manual reconciliation. Point solutions solve each function well individually but leave integration as the business's own problem — usually solved with fragile Zapier-style glue or, more commonly, not solved at all (staff manually re-keying data between systems).
- **One login, one permission model.** Combined with the [SSO design](../03-identity-and-access.md#single-sign-on-authelia), staff get one set of credentials instead of five — and a leaver's access to *all* of accounting/inventory/HR/CRM is revoked in the same one action that revokes everything else.
- **Cost at scale**, per [08 — Cost & BOM](../08-cost-and-bom.md): five separate SaaS subscriptions at 60 seats plausibly exceeds $1,000+/month combined; ERPNext is self-hosted at infrastructure cost only.

## Consequences

**This is the ADR with the most real trade-off risk in the whole design — stated directly:**

- **Best-of-breed point solutions are usually more polished per function.** Square's POS UX, QuickBooks' accountant ecosystem (most external accountants/bookkeepers already know QuickBooks, not ERPNext), and a dedicated CRM's sales-pipeline features are each individually more refined than ERPNext's equivalent module. This is a genuine UX and workflow cost, accepted here in exchange for integration — not a free win.
- **External accountant friction.** If the business's external accountant/auditor only works in QuickBooks, ERPNext's accounting module either needs an export/reconciliation workflow to hand data over, or the accountant needs to learn a system they don't otherwise use. This is a real, recurring friction point worth surfacing to the business owner *before* committing to this design, not after.
- **One system, one blast radius.** A misconfiguration or outage in ERPNext takes down accounting, inventory, POS, HR, *and* CRM simultaneously — point solutions would only lose one function at a time. This is partially mitigated by treating ERPNext as a Tier-1 critical VM in the [backup schedule](../07-disaster-recovery.md#backup-schedule--retention) (4-hour backup interval, same tier as the domain controllers), but the concentration risk is real and worth naming.
- **Self-hosted means self-supported.** No vendor support line for ERPNext functional questions ("how do I set up a multi-currency invoice") the way a QuickBooks support chat would provide — troubleshooting relies on ERPNext's community forum/docs and the admin's own learning curve on a genuinely large piece of software.

## Revisit if

The external-accountant friction turns out to be a bigger operational cost than expected, or if a specific ERPNext module (POS, HR) proves meaningfully worse than a dedicated point solution in practice — at which point a hybrid approach (ERPNext for accounting/inventory, a dedicated POS or CRM bolted on) is the natural next iteration, accepting the integration cost back in exchange for the better point tool.
