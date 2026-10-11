# ADR-0007: Configuration distribution: snapshot events and consumer-side caches

- Status: Proposed
- Date: 2026-10-11
- Scope: Module 1

## Context

The loan journey reads partner, program, arrangement and limit configuration
up to 5,000 times a second, with ≤ 10 ms p99 per read (NFR-UP01-P07, C03).
Approved changes must take effect within 60 s (P09), and suspensions or
revocations within 60 s even when caches are in use (A04, P10). The journey
must keep working on the last approved configuration for at least 4 hours if
Module 1 is down (A03).

## Decision

1. Module 1 publishes every activation, suspension and retirement as a
   **snapshot event** on Kafka (compacted topics keyed by aggregate ID), via
   the outbox (ADR-0002).
2. Each consuming service keeps a **local read model** of only the
   configuration it needs: in memory, backed by its own database table or
   Redis, rebuilt from the compacted topic on start-up. Reads are local, so
   there is no network call on the hot path.
3. Consumers evaluate **effective times** themselves: a scheduled version is
   delivered ahead of time and switched on locally at `effective_from`.
4. **Priority changes** (partner suspended, API client revoked or restricted)
   go to a dedicated high-priority topic, and the gateway also blocks the
   partner directly. A consumer that misses them still rejects the call at the
   gateway.
5. Module 1 exposes a versioned **read API** (OpenAPI) with an `asOf`
   parameter as a fallback for cold start and for back-office use, never on the
   per-application hot path.
6. A shared client library (Module 0) gives consumers the topic subscription,
   local store, effective-time switching and staleness metrics, so each
   service does not build its own.

## Alternatives considered

- **Synchronous REST lookup per application with a TTL cache.** Couples
  every loan to Module 1's availability and makes the 60 s propagation and
  4-hour outage targets hard to meet together.
- **Spring Cloud Config / a key-value config server.** Built for application
  settings, not for tenant-scoped, approved, versioned business configuration.
- **Shared Redis written by Module 1.** It becomes a shared database by
  another name (ADR-0002).

## Consequences

- Configuration propagation lag becomes a monitored metric with an alert at
  60 s (NFR-UP01-O02).
- Event schemas for configuration are a public contract and must stay
  backward compatible.
- Rebuilding a read model from a compacted topic must be fast. It is tested at
  1,000 programs × 20 versions.
