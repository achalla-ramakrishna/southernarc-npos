# ADR-0006: One partner-configuration service, modular inside

- Status: Proposed
- Date: 2026-10-11
- Scope: Module 1

## Context

Module 1 covers partners, programs, arrangements, limits, DLG, commercials,
credentials, reference data and approvals. Many rules cross these objects (a
program needs an active arrangement and limit set; go-live needs all of them;
approval of one may change several). Write volume is tiny (40–200 changes a
month, 100 concurrent users), while read volume from the loan journey is high
but served from consumer caches (ADR-0007).

## Decision

Build Module 1 as **one Spring Boot service** (`partner-config-service`) with
**one MySQL schema**, structured internally as separate packages per
sub-domain:

```
partner-config-service
  tenant/         partner/        program/
  colending/      exposure/       commercials/
  credentials/    approval/       referencedata/
  readiness/      packaging/      audit/
```

Sub-domains talk to each other only through their application services (no
reaching into another package's repositories). This boundary is checked with
ArchUnit tests, so a sub-domain can be split into its own service later if
needed.

Partner credentials integrate with Keycloak and the gateway through an adapter
inside this service (ADR-0009). Documents go to a separate document service.

## Alternatives considered

- **One microservice per aggregate** (partner-service, program-service,
  arrangement-service…). Cross-object rules would become distributed
  transactions and sagas for a low-volume admin workload, and more to deploy
  and monitor for a small team.
- **Separate read service (CQRS) for the loan journey.** Not needed:
  consumers keep their own read models from events.

## Consequences

- One deployable for the whole module; simpler to test and release.
- The internal boundaries must be kept disciplined (ArchUnit in CI).
- If one sub-domain grows (for example credentials, if it turns into a full
  partner developer portal), it can be extracted along the existing package
  boundary.
