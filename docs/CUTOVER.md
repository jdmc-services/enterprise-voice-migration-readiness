# Cutover and service recovery runbook

This is a synthetic template. Replace placeholders in a private customer-controlled change record. Do not execute against production directly from this repository.

| Stage | Owner | Action and evidence |
| --- | --- | --- |
| T−5 business days or agreed interval | Project manager/customer | Reconcile scope, authorizations, communications and open dependencies; confirm carrier dates |
| T−1 | Engineering/carrier | Capture approved configuration baseline; verify contacts, access, routing and contingency feasibility |
| Before activation | Customer change owner | Record go/no-go; hold if readiness gates fail; confirm whether an order can still be postponed |
| Activation window | Carrier/engineering | Follow accepted order and approved change; log timestamps and verify exact activated IDs |
| Validation | Engineering/service owners | Test every agreed service category; reconcile failures and partial activation; record evidence |
| Incident | Incident owner | Declare severity, preserve logs, engage providers, approve recovery route and issue timed updates |
| Stabilization | Service desk/customer | Confirm monitoring, support ownership and business acceptance |
| Closeout | Customer/finance | Reconcile inventory and bills; authorize any legacy disconnection after dependency review |

## Recovery is stage-dependent

1. **Before number activation:** an approved configuration change may be reversible. Carrier-order cancellation or postponement is subject to its cutoff and acceptance process; confirm status before assuming the old service remains unaffected.
2. **After number activation:** restoring a local configuration does not return number ownership or routing to the losing provider. Where previously approved and technically supported, alternate routing or forwarding may restore some functions. Validate caller identity, emergency calling, capacity and special-service impact before relying on it.
3. **Carrier corrective action:** a failed or partial port requires coordination with the responsible providers. Port reversal or re-porting is carrier-dependent and may need new authorization, orders and time. This repository promises no instantaneous rollback.

Stop additional waves during unresolved critical failures. Escalate emergency calling failures immediately under the approved incident procedure. Record affected IDs and categories without exposing customer details publicly. Resume only after evidence, responsible owners and the customer change authority approve.

For each contingency, document trigger, approving owner, technical executor, prerequisites, expected limitation, communication owner and the evidence needed to exit recovery. Do not invent working recovery paths after activation.
