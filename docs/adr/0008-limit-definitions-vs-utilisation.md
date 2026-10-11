# ADR-0008: Limit definitions in Module 1, utilisation in Module 7

- Status: Proposed
- Date: 2026-10-11
- Scope: Module 1

## Context

UC-01.04 configures exposure limits and DLG. Decisioning and disbursement must
check and update utilisation in ≤ 50 ms p99, with **no over-utilisation**
under 2,000 concurrent requests (NFR-UP01-P08, BR-01.04-03). Utilisation
changes with every loan; definitions change a few times a month.

## Decision

- **Module 1 owns limit and DLG definitions:** the approved, versioned
  values, thresholds, temporary caps, and the DLG instrument's status.
- **Module 7 (Co-lending Allocation and Exposure) owns utilisation:** it
  reserves exposure when a loan is approved, confirms it on disbursement,
  releases it on cancellation, and enforces the caps atomically. It learns the
  limits from Module 1's events (ADR-0007).
- Module 1 shows utilisation on its dashboards by reading Module 7's API or
  events, not by storing it.

## Alternatives considered

- **Utilisation counters inside Module 1.** This puts a high-volume,
  latency-critical write path into a low-volume admin service and couples
  every loan to it.

## Consequences

- Until Module 7 exists, limits are defined and approved but not enforced at
  runtime. This is acceptable because nothing runs loans until Modules 3–9 exist.
- The limit event schema is designed with Module 7's needs in mind (scope keys:
  partner, program, arrangement, borrower; period: daily, monthly; temporary
  caps with start and end).
