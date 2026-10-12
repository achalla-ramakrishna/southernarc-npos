# Architecture decision records

Each record states one decision that is costly to reverse: the context, the
decision, the alternatives considered, and the consequences. Records are never
edited after they are accepted; a later record supersedes them instead.

Status values: **Proposed** (under review), **Accepted**, **Superseded by ADR-nnnn**.

| ADR | Title | Scope | Status |
|---|---|---|---|
| [0001](0001-technology-baseline.md) | Technology baseline | Platform | Proposed |
| [0002](0002-database-per-service-and-events.md) | Database per service, Kafka events with a transactional outbox | Platform | Proposed |
| [0003](0003-multi-tenancy-model.md) | Multi-tenancy: tenant as isolation boundary, lenders as parties | Platform | Proposed |
| [0004](0004-immutable-effective-dated-versions.md) | Immutable, effective-dated configuration versions | Module 1 | Proposed |
| [0005](0005-generic-maker-checker-change-requests.md) | Generic maker-checker change requests with a configurable approval matrix | Module 1 | Proposed |
| [0006](0006-single-partner-config-service.md) | One partner-configuration service, modular inside | Module 1 | Proposed |
| [0007](0007-configuration-distribution.md) | Configuration distribution: snapshot events and consumer-side caches | Module 1 | Proposed |
| [0008](0008-limit-definitions-vs-utilisation.md) | Limit definitions in Module 1, utilisation in Module 7 | Module 1 | Proposed |
| [0009](0009-partner-credentials-in-keycloak.md) | Partner credentials in Keycloak and the gateway; no secrets in our database | Module 1 | Proposed |
| [0010](0010-configuration-packages.md) | Configuration packages for promotion between environments | Module 1 | Proposed |
| [0011](0011-installation-and-release-management.md) | Installation and release management | Platform | Proposed |
| [0012](0012-versioned-content-as-json-with-extracted-columns.md) | Store versioned content as JSON with extracted columns | Module 1 | Proposed |

Template: Context → Decision → Alternatives considered → Consequences.
