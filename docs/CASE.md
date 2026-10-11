# Synthetic enterprise case

Fictional organization: **Example Enterprise**, with 20 fictional sites and 20,000 number identifiers. This scenario is independently constructed, not an anonymized extract of a real customer. There are no real telephone numbers.

[data/inventory.csv](../data/inventory.csv) contains 20 aggregate site records. Each site has 1,000 IDs: 800 standard, 100 contact-center, 50 emergency-location-associated, and 50 special-purpose. Within each site range, standard IDs occupy the first 800 positions, contact-center the next 100, emergency-location-associated the next 50, and special-purpose the last 50. The categories are mutually exclusive for counting; emergency calling obligations may also apply to standard and contact-center services. Special-purpose classifications require discovery, including fax, alarms, elevators, door phones, and other devices; their existence and supported migration paths cannot be inferred from a telephone-number list.

Totals: 16,000 standard + 2,000 contact-center + 1,000 emergency-location-associated + 1,000 special-purpose = **20,000**. IDs NUM-00001 through NUM-20000 describe population ranges, not dialable numbers. The aggregate inventory is insufficient for submitting a live port order.

[data/waves.csv](../data/waves.csv) divides this population into five non-overlapping waves: 100 + 1,900 + 4,000 + 6,000 + 8,000 = 20,000. This is a capacity-planning scenario, not a carrier-accepted schedule. Sites 01–02 span the first two waves; subsequent waves cover sites 03–06, 07–12, and 13–20. All critical service types must pass applicable readiness gates before their own migration, regardless of wave size.

Assumed objective: assess migration options and create a controlled transition from an existing enterprise voice environment with possible Avaya and SBC dependencies. No specific Avaya release, carrier, SBC model, target platform, or contract is assumed to be compatible. [Dependencies](DEPENDENCIES.md) explains what must be established.

The fictional sponsor requests reduced complexity and predictable operating costs. These are hypotheses to test against an agreed baseline. Actual savings, continuity, successful ports, or compliance are not claimed.
