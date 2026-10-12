# ADR-0012: Store versioned content as JSON with extracted columns

- Status: Proposed
- Date: 2026-10-12
- Scope: Module 1

## Context

Each configuration version (partner profile, program, arrangement, limit set,
DLG cover, commercials) holds a large nested document: a program version alone
has loan parameters, a pricing grid, a list of charges, journey options,
documents, templates and links. Versions are immutable once approved
(ADR-0004), are almost always read or written whole, and are validated by the
domain layer, which already holds the rules (invariants G1–G9, C1–C6 and so on).

A few fields **are** queried across versions or across aggregates:

- PAN, CIN, LLPIN and GSTIN uniqueness (BR-01.01-01),
- which programs use a given rule set (gap G-3 from the worked example),
- which programs reference an arrangement, limit set or DLG cover (impact of
  suspension or change),
- status and effective dates (scheduler, point-in-time reads).

Fully normalising the content would mean 25–35 extra tables (charges, tenures,
risk grades, journey options, documents, fee-sharing rows…) whose rows are
always loaded and saved together, plus a migration every time a field is added.

## Decision

1. Each version table stores the version's terms in a **`content` JSON
   column**, exactly as the API's `…Content` schema (see the contracts),
   with a `content_schema_version` number.
2. Lifecycle and query fields are **real columns**: IDs, version, status,
   effective_from / effective_to, change request, approval time, audit columns.
3. Fields queried from inside the content are **stored generated columns**
   extracted from the JSON and indexed (for example
   `rule_set_id GENERATED ALWAYS AS (content->>'$.links.ruleSet.ruleSetId') STORED`).
   They cannot drift from the JSON, because MySQL computes them.
4. Uniqueness that spans aggregates is held in **dedicated tables** with
   unique keys (for example `partner_identifier` for PAN, CIN, LLPIN, GSTIN),
   not in JSON.
5. The database enforces what it can enforce cheaply and reliably:
   - at most one ACTIVE version per aggregate (unique index on a generated
     "active marker" column),
   - gap-free unique version numbers per aggregate,
   - same-tenant references (composite foreign keys on `(tenant_id, id)`),
   - closed value sets (CHECK constraints),
   - append-only audit (triggers plus database privileges).

   Everything else is enforced by the domain layer, which runs on save and on approval.
6. JSON content changes are **additive within a schema version**. A
   breaking change to a content shape increments `content_schema_version`, and
   the service reads both until old versions are migrated or retired.

## Alternatives considered

- **Fully normalised tables.** Strong database-level typing, but many tables,
  many joins to load one version, and a schema migration for every new
  program field. Configuration changes are exactly what the business wants to
  make fast.
- **A document database (for example MongoDB) for configuration.** Adds a
  second database technology to every installation, including banks'
  on-premise ones. MySQL's JSON support covers the need.
- **JSON without extracted columns.** Cross-version queries would need full
  scans with JSON functions, and uniqueness could not be enforced.

## Consequences

- Validation of content structure lives in the service (JSON Schema from the
  contracts plus domain invariants). The database only checks that `content`
  is a JSON object.
- Reporting that needs individual content fields uses Module 14's read store,
  fed by events, not ad-hoc JSON queries on this schema.
- Adding a new queryable field means adding a generated column and index,
  not restructuring tables. A `VIRTUAL` column with an index is added in
  place; a `STORED` one rebuilds the table, which takes seconds at Module 1's
  sizes.
