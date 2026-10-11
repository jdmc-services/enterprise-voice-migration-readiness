# Service, Avaya, and SBC dependencies

Inventory must join customer-authorized number records with services, locations, ownership, routes, contracts, billing, and devices. A number list alone cannot reveal dependencies or consent to transfer service.

| Dependency | Required evidence | Readiness condition |
| --- | --- | --- |
| Port authorization | Customer service record, authorized signatory, provider-required fields and acceptance | Losing and gaining provider processes confirmed; discrepancies resolved |
| Avaya environment | Exact product/release, support status, licensing, dial plan, trunk configuration | Design reviewed against that version and tested with intended service |
| Session border controller | Model, firmware, supported capacity, certificates, codecs, DTMF, SIP transport and routing | Version-specific evidence plus representative end-to-end tests |
| Network | Firewall policy, bandwidth, QoS, DNS/NTP, resilience, address translation | Approved paths, measured performance and failure tests |
| Contact center and recording | Queues, IVR, transfers, caller identity, recording and retention requirements | End-to-end functional tests and authorized access/retention review |
| Emergency calling | Responsible location owners, applicable obligations, routing, callback, notifications, location data | Specialist-approved test method; required location/routing evidence accepted |
| Fax and special lines | Device/function owner, analog requirements, power and monitoring dependencies | Supported replacement or retained service documented and tested |
| Toll-free and non-geographic services | Separate inventories, responsible parties and provider transfer process | Separate process and acceptance criteria confirmed |

An interoperability listing is evidence of a documented test context, not a guarantee for a different release, configuration, network or service. Consult the [public source register](../SOURCES.md), provider documentation, and qualified engineering review. Do not advertise this repository as Avaya/SBC certification.

Emergency service test calls require an authorized, coordinated procedure; never place uncoordinated test calls to an emergency center. Direct dialing, notifications, dispatchable location and other applicable requirements must be assessed for the actual system, jurisdiction and implementation. This example does not certify compliance.

Use named, least-privilege roles, MFA where supported, approved temporary access, logged changes, certificate renewal ownership and protected customer data. Carrier credentials, recordings, bills and configuration exports belong in customer-approved private systems, not this repository.
