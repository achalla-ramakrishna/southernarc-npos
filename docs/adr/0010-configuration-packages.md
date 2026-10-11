# ADR-0010: Configuration packages for promotion between environments

- Status: Proposed
- Date: 2026-10-11
- Scope: Module 1

## Context

Today partner set-up reaches production through a hand-written SQL release
document reviewed by several people, and pre-production is not used
(discovery O3, O8). Configuration must move through environments (SIT,
sandbox, UAT, production) as a versioned package with a comparison of changes
(NFR-UP01-CF04), and must be applied the same way to Northern Arc's and banks'
installations (improvement MT7).

## Decision

1. Approved configuration can be **exported** as a configuration package: a
   JSON document containing the selected aggregates and versions (partner,
   programs, arrangement, limits, commercials, referenced reference data), with
   a manifest, a schema version and a digital signature.
2. **Import** into another environment: verify the signature and schema
   version; show a **diff** against what is already there; run all invariants
   as a dry run; then create change requests in the target environment, so
   the target's own maker-checker applies. Nothing bypasses approval.
3. Environment-specific values (credentials, endpoints, escrow account in
   sandbox vs production) are **never** in packages. They are bound in the
   target environment.
4. Packages are idempotent: importing the same package twice changes nothing.
5. Every live partner's configuration has a stored package, which the
   regression pack (NFR-UP01-CF05) uses to run a sample loan per partner
   before each release.

## Alternatives considered

- **SQL scripts with dry run and rollback** (quick win QW2 for the current
  system). Fine as a stopgap for the existing platform, but they bypass domain
  rules and tie configuration to table layout.
- **Database replication between environments.** This mixes test and
  production data and ignores approvals.

## Consequences

- Package format is a versioned public contract with backward-compatible
  readers.
- On-premise bank installations receive configuration the same way as code:
  as signed, reviewable artefacts.
