# Nexus Human-Gated Live Trading Authority

**Authority ID:** NEXUS-LIVE-AUTHORITY-20261002-001  
**Decision date:** 2026-10-02 (America/Los_Angeles)  
**Decision:** User approved the bounded human-gated live-trading model.  
**Activation state:** APPROVED_PENDING_CANONICAL_RECONCILIATION_AND_RUNTIME_VERIFICATION  
**Repository effect:** Documentation of approval and activation conditions; no executable permission grant.

## Approved boundary

Nexus may prepare, validate, route, execute, reconcile, and receipt a live trade only after the user gives action-time authorization for that exact ticket. This approval establishes the conditional governance model; it is not approval of any order.

A ticket must identify the broker, account, live environment, symbol, side, quantity or notional, order type, time in force, exposure, risk, and unique operation/client-order identity. Authorization is single-use and bound to those terms. Any term change requires fresh ticket authorization. Old authorization, research conclusions, paper approvals, and prior fills cannot authorize a new live trade.

No autonomous, blanket, unattended, transfer, withdrawal, margin, short-sale, derivatives, or cross-workflow authority is granted by this amendment. Those capabilities require separate explicit governance. Existing narrower instrument and execution restrictions continue to apply.

## Activation conditions

All conditions must have recorded readback evidence before operational activation:

1. Repair the outstanding POWL canonical reconciliation exception by recording the existing fill in the local PostgreSQL append-only ledger through the verified existing receipt contract. Reuse the original operation and broker order identities. Read back the canonical receipt and reconcile the linked remote receipt and Tracker projection. Do not submit another order.
2. Register this authority decision in the verified canonical governance contract. Discover the actual schema, columns, functions, roles, and current constraints before writing; do not invent a table or relax a constraint.
3. Bind a specifically named live execution surface and its workflow to this authority. Verify account/environment isolation and ticket authorization enforcement. Paper and research adapters retain their present authority.
4. Verify rejection of an unauthorized ticket, a changed ticket, and a reused authorization without submitting an order. Verify duplicate prevention and recovery from ambiguous submission. Reconciliation failures must stop new execution through this lane until resolved.
5. Verify canonical authorization persistence before submission, broker acceptance/terminal readback, append-only result persistence, and the remote Live Trades projection. Existing broker evidence is not proof that these new controls are enforced.
6. Publish an activation receipt containing canonical authority ID, selected surface, verification evidence, and exact enabled scope. GitHub documentation or a merge alone cannot satisfy this condition.

If any condition is missing, activation stays pending. No new live order is authorized by this document.

## Authority and reconciliation

Local PostgreSQL remains semantic authority. Supabase and Tracker retain their existing bounded operating/projection roles; no cutover is performed. Broker evidence establishes execution facts. Missing canonical evidence means full-stack reconciliation is incomplete, even when a broker fill is documented.

Use one immutable operation/client-order identity throughout authorization, submission, broker readback, canonical ledger, and Tracker. After a timeout or uncertain submission, query the broker before any retry. After a logging failure, repair the receipt only; never resubmit the trade to repair logging.

The existing Nexus Live Trade Execution and Receipt Process remains the execution procedure, subject to this amendment's activation conditions. Its receipt packet and session-start readback requirements continue to apply.

## Capability review

| Domain | Approved scope | Failure control |
|---|---|---|
| Capital | Only an exact action-time authorized ticket | No ticket authorization means no submission |
| Broker | Only the specifically verified live surface | Account/environment mismatch stops execution |
| Canonical records | Bounded authority and receipt records through verified contracts | Missing contract or readback keeps activation pending |
| Recovery | Existing operation and broker identity | No blind retry; repair receipts separately |
| Paper/research workflows | Existing scope | No inheritance of live authority |
| Revocation | User may suspend this lane | Stop new submissions; preserve receipts and reconciliation work |

## Recorded review state

The current repository adapter inventory and machine registry describe Paper-only paths and deny live trading. They remain unchanged by this documentation patch. A future reviewed adapter patch must describe the verified live surface without broadening existing Paper workflows or setting a global live permission.

The current POWL receipt packet reports a local canonical reconciliation exception. This review did not query the laptop database or independently read the broker. No runtime activation or completed reconciliation is asserted.

## Resume checkpoint

Next allowed action: verify the available laptop connection, inspect the current canonical receipt/governance contracts read-only, and repair only the missing POWL receipt. Then complete the activation conditions above. User approval of the conditional governance model is already recorded; do not request it again.
