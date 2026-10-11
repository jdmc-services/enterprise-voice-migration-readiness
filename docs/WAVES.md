# Porting waves and approval gates

[data/waves.csv](../data/waves.csv) contains the synthetic range allocations. Every ID appears once. The pilot covers standard IDs at SITE-01; the remaining pilot-site services are assessed in Wave 2. Pilot success does not automatically establish readiness for emergency, contact-center, or special-purpose services.

Before each wave, obtain: approved scope and inventory; customer authorization; carrier acceptance and confirmed window; category-specific test evidence; emergency and special-service owner acceptance; approved routing and recovery options; staffing; communications; change approval; and named incident escalation contacts in the customer's private system.

**Go/no-go:** engineering confirms technical evidence, the carrier confirms order status, service owners confirm business readiness, and the customer change owner authorizes execution. The project manager records the decision and escalates gaps. Missing critical evidence results in a hold, reduced scope or a new approved window. A carrier-confirmed order is not proof that the business service will work end to end.

Communicate expected impact, window, user actions, support route and update cadence before cutover. After activation, validate inbound/outbound routes, caller identity, transfers, queues, approved emergency-calling tests, special lines and monitoring as applicable. Record results, actual activated counts, unresolved defects and acceptance.

Do not disconnect the old circuit simply because a port-complete message arrived. Review remaining services, dependency evidence, contracts and billing before the customer authorizes disconnection. See [cutover runbook](CUTOVER.md).
