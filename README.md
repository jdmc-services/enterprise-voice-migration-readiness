# Enterprise Voice Migration Readiness

A synthetic portfolio showing how a large number-porting program can be organized, governed, and evaluated while protecting service continuity.

**Experience boundary:** I have worked on porting more than 20,000 numbers. That is my reported professional experience; this repository does not independently verify it. The fictional 20,000-number case below demonstrates a project-management approach. Its roles, decisions, schedules, prices, and results are illustrative, not records of my employment or client work. It does not establish that I personally performed every activity described.

My focus here is practical: understand what must move, identify dependencies, define accountable owners, control the cutover, and establish evidence before closing a wave.

## Start here

Read [START-HERE.md](START-HERE.md) for a five-minute route through the material. The [case overview](docs/CASE.md), [wave plan](docs/WAVES.md), and [risk register](data/risks.csv) show the core approach. The [benefit model](docs/BENEFITS.md) separates assumptions from outcomes.

| Topic | What it demonstrates |
| --- | --- |
| Service and number inventory | Understanding what must move |
| Avaya/SBC dependencies | Recognizing compatibility requirements |
| Porting sequence and recovery | Planning for continuity |
| Emergency calling and special lines | Identifying critical dependencies |
| Provider comparison | Evaluating options without vendor favoritism |

## Boundaries

All organization, site, number, and commercial examples are synthetic. Number IDs are non-dialable identifiers. No customer records, employer names, account numbers, carrier bills, internal designs, or confidential agreements belong here. No provider endorses this work. Product names identify possible dependencies and do not imply affiliation or certification.

Commercial consulting and referral discussions are independent of employment and nonprofit activities. This portfolio does not establish a reseller appointment, referral agreement, commission entitlement, legal compliance certification, or production deployment readiness. See [engagement boundaries](docs/ENGAGEMENT.md) and [privacy](PRIVACY.md).

The case is a US-oriented planning example. Service availability, emergency calling, portability, contractual obligations, and technical compatibility require confirmation for each real engagement. Public sources are recorded in [SOURCES.md](SOURCES.md).

## Use and verification

The documents can be read directly on GitHub. Locally, run `powershell -NoProfile -File .\scripts\validate-repository.ps1` from the extracted folder, or use `pwsh` with the same arguments. See [VALIDATION.md](VALIDATION.md) for what was actually tested and its limits.

To publish a copy to your GitHub account, use [START-PUBLISH.md](START-PUBLISH.md). Preparation does not publish anything; preview is the default and creation is private unless explicitly requested otherwise.
