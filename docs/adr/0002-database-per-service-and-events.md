# ADR-0002: Database per service, Kafka events with a transactional outbox

- Status: Proposed
- Date: 2026-10-11
- Scope: Platform

## Context

Today shared tables are changed with SQL release documents that need approval
from the owners of other partners, and a change for one partner breaks another
(discovery O3). Webhooks must never report something that did not happen, or
miss something that did.

## Decision

1. Each service owns its own MySQL schema. No service reads or writes another
   service's tables. Cross-service data access is through the owner's API
   (queries) or its events (state changes).
2. State changes are published as domain events on Kafka using the
   **transactional outbox**: the service writes the business change and an
   `outbox` row in the same database transaction; Debezium streams outbox rows
   to Kafka.
3. Events carry a full snapshot of the new state, an event ID, tenant ID,
   aggregate ID and version, so consumers can process them idempotently and
   out of order (they keep the highest version they have seen).
4. Consumers are idempotent: they record processed event IDs.
5. Event schemas are registered and versioned in the Schema Registry with
   backward compatibility enforced in CI.

## Alternatives considered

- **Shared database.** It is how the current platform works and is the root
  cause of cross-partner breakage.
- **Publish to Kafka directly after commit.** This loses events when the
  process dies between the commit and the publish.
- **Polling outbox publisher instead of Debezium.** Simpler to run but adds
  latency and load. It stays acceptable as a fallback for installations that
  cannot run Debezium.

## Consequences

- Reporting across services needs its own read store (Module 14), fed by events.
- Developers must think in eventual consistency after the synchronous decision
  boundary.
- Every service gets the outbox, idempotent consumer and audit pieces from a
  shared library (Module 0), so this is not re-implemented per service.
