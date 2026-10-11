# ADR-0004: Immutable, effective-dated configuration versions

- Status: Proposed
- Date: 2026-10-11
- Scope: Module 1

## Context

Programs, arrangements, limits, commercials and partner profiles change over
time, while loans already in flight must keep the terms they started with
(BR-01.02-05, BR-01.03-04, BR-01.06-03). Auditors must see the exact
configuration in force at any past moment (NFR-UP01-AU04), and rollback must
take at most 5 minutes (NFR-UP01-A06). Today, configuration is changed in place
with SQL.

## Decision

1. Configuration terms live in **version** records that are never updated
   after approval. Only their status moves forward (Scheduled → Active →
   Superseded / Retired).
2. Each version has `effective_from` and an optional `effective_to`. For one
   identity, effective periods never overlap (invariant G9). Activating a new
   version closes the previous one at the same instant.
3. A future-dated version is `Scheduled` and activates automatically. It can be
   cancelled before then (NFR-UP01-CF07).
4. Every consumer records the **version ID** it used (for example the
   application stores `programVersionId`, `arrangementVersionId`,
   `limitSetVersionId`, `commercialVersionId`) (NFR-UP01-AU03).
5. **Rollback** is a new change request whose content is copied from an
   earlier version. It goes through the same approval and produces a new
   version number. History is never rewritten.
6. Activation at the effective time is done by a scheduler inside the service
   that emits the activation event. Consumers also hold the effective times,
   so they switch correctly even if the event arrives late.

## Alternatives considered

- **Update in place with an audit trail.** Simpler tables, but no
  point-in-time view, and in-flight loans would silently change terms.
- **Temporal tables (system-versioned).** MySQL has no native support, and
  system time is not business effective time.

## Consequences

- Version tables grow (1,000 programs × 20 versions is small; no concern).
- Every read API takes an optional `asOf` timestamp.
- The UI must make "draft", "scheduled" and "active" visually distinct, and
  show a diff between any two versions (NFR-UP01-U02).
