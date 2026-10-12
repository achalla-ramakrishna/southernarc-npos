# Module 1: contracts

Step 4 of the module. Status: **draft for review**.

These contracts define how the outside world talks to `partner-config-service`.
They are written **before** any code. The service is built to match them, and CI
checks that it still does (contract tests, schema compatibility).

| Contract | File | Used by |
|---|---|---|
| Admin API | [openapi/admin-api.yaml](openapi/admin-api.yaml) | Back-office console (React), platform admin tooling |
| Read API | [openapi/read-api.yaml](openapi/read-api.yaml) | Other nPOS services: cold start, back-office lookups, point-in-time queries |
| Shared schemas | [openapi/common.yaml](openapi/common.yaml) | Both APIs (and mirrored in the event payloads) |
| Events | [asyncapi/events.yaml](asyncapi/events.yaml) | Every service that keeps a local copy of configuration (ADR-0007) |
| Error catalogue | [error-catalogue.md](error-catalogue.md) | Both APIs, the UI, partner-facing error mapping |
| Worked example | [worked-example-fatakpay.md](worked-example-fatakpay.md) | Reviewers: shows the contracts working end to end |

## Conventions

These apply to every endpoint and event in the module, and are intended to
become the platform standard (Module 0).

### Base paths and versioning

| API | Base path | Audience |
|---|---|---|
| Admin | `/admin/partner-config/v1` | Internal users through the back-office console |
| Read | `/internal/partner-config/v1` | Other nPOS services only (not exposed to partners) |
| Partner intake | `/partner/v1/credential-requests` | Partner technical contacts, through a one-time link (UC-01.05 step 4) |

- The major version is in the path. Within a major version, changes are
  **additive only**: new optional fields, new endpoints, new enum values
  (clients must tolerate unknown enum values and fields).
- A breaking change means a new major path, with the previous one supported for
  the support window in ADR-0011 (N and N-1).

### Authentication and tenant

- Users: OAuth 2.0 / OIDC bearer token from Keycloak (corporate SSO with MFA).
  Services: OAuth 2.0 client credentials (scope `partner-config.read`).
- The **tenant comes from the token**, never from a header or the URL
  (ADR-0003). A request can only see its own tenant's data, plus co-lending
  arrangements where its tenant is a party.
- Authorisation is by role per operation. Each operation lists its roles in
  `x-roles`, enforced by the service, not just by the UI (NFR-UP01-S02).

### Drafts, versions and change requests

The APIs follow the domain model's pattern (ADR-0004, ADR-0005):

1. **Create or copy a draft:** `POST …/versions` creates a version in `DRAFT`
   and a change request in `DRAFT` that owns it. The response carries both IDs.
2. **Edit the draft:** `PUT …/versions/{version}` with `If-Match: <etag>`.
   Only drafts and returned versions can be edited.
3. **Validate (optional, any time):** `POST …/versions/{version}/validation`
   returns every rule violation at once without submitting (NFR-UP01-U01).
4. **Submit:** `POST /change-requests/{id}/submission`. Validation runs again;
   approval steps are generated from the approval matrix.
5. **Decide:** `POST /change-requests/{id}/decisions` with `APPROVE`,
   `RETURN` or `REJECT` on the current step.
6. On the last approval the version becomes `SCHEDULED` or `ACTIVE`, and the
   event is published.

Status changes (suspend, reinstate, offboard, retire, rollback) are also
change requests, created through their own endpoints.

### Idempotency

Every `POST` that creates something or triggers an action accepts an
`Idempotency-Key` header (a UUID chosen by the client). Repeating a request
with the same key within 24 hours returns the original response and does not
create a second resource. The same key with a different body returns
`409 IDEMPOTENCY_KEY_REUSED`.

### Optimistic concurrency

Drafts return an `ETag`. Updates must send `If-Match`. A stale ETag returns
`412 PRECONDITION_FAILED`, so two people editing one draft cannot overwrite
each other.

### Errors

All errors use **RFC 9457 Problem Details** (`application/problem+json`) with
an nPOS error `code`, the business rule ID where one applies, and a
`violations` list for validation errors. See the
[error catalogue](error-catalogue.md).

| Status | Meaning |
|---|---|
| 400 | Malformed request (bad JSON, wrong type, missing required field) |
| 401 / 403 | Not authenticated / role or tenant not allowed |
| 404 | Not found **in your tenant** (never reveals other tenants' data) |
| 409 | Conflict with current state (wrong status for the action, duplicate, idempotency key reused) |
| 412 | ETag mismatch |
| 422 | Business rule violated (each violation lists its BR ID) |
| 503 | A dependency (DMS, ERP, Keycloak) is unavailable; safe to retry |

### Data formats

| Kind | Format |
|---|---|
| IDs | Technical IDs: UUIDv7 strings. Business IDs: `PTR-000123`, `PRG-000456`, `CLA-000078`, `LST-…`, `DLG-…`, `COM-…`, `CR-…` |
| Money | `{ "amountPaise": 5000000 }`: integer paise; never decimals |
| Rates and percentages | Integer basis points: `1850` = 18.50% |
| Timestamps | RFC 3339 with offset; stored in UTC. Effective times are usually entered in IST (`+05:30`) |
| Dates | `YYYY-MM-DD` |
| Enums | `UPPER_SNAKE_CASE` |
| Pagination | Cursor-based: `?limit=50&cursor=…`; response has `items` and `nextCursor` |

### Point-in-time reads

Read API endpoints that return configuration take an optional `asOf`
timestamp and return what was in force at that moment (NFR-UP01-AU04).
Without `asOf`, they return what is in force now.

### Events

- Kafka topics are **compacted, one key per aggregate**. Each message carries
  the aggregate's **complete current snapshot**: its status, the version in force,
  and any scheduled future versions. A consumer that reads a topic from the
  start always ends up with the full current configuration (ADR-0007).
- One **priority topic** carries urgent control messages (suspensions,
  revocations) that consumers act on immediately.
- Envelope: **CloudEvents 1.0** attributes in Kafka headers (binary mode).
- Payload: JSON validated against **JSON Schema** registered in the Schema
  Registry, with backward compatibility enforced in CI. JSON Schema is chosen
  over Avro so the same schemas serve the REST contracts and the events.
  This settles the "Avro or Protobuf" option left open in ADR-0001; to confirm.

## Deviations from the domain model raised by this step

| # | Change | Why |
|---|---|---|
| D1 | Events are **snapshots per aggregate**, so the domain events listed in the domain model become the `trigger` field inside a snapshot message, not separate topics | Compacted topics keep only the latest message per key. Separate event types per key would lose the active version when a scheduled one is published |
| D2 | Added `…VersionScheduled` and `…ScheduleCancelled` triggers | Consumers must learn about future versions before they take effect (ADR-0007 §3) |
| D3 | Partner documents are uploaded straight to the document service using a pre-signed URL; Module 1 stores only the reference | Keeps 20 MB uploads off the configuration service (NFR-UP01-P03, D02) |

The domain model will be updated once these are agreed.
