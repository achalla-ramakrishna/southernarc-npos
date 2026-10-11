# ADR-0003: Multi-tenancy: tenant as isolation boundary, lenders as parties

- Status: Proposed
- Date: 2026-10-11
- Scope: Platform

## Context

nPOS serves Northern Arc and banks. A bank may use a hosted, shared
installation or its own on-premise installation (South Indian Bank does).
Bank users must see only their own data (NFR-UP01-S03). A co-lending
arrangement, however, involves **two** lenders that both need to see and
approve its terms (UC-01.03).

## Decision

1. A **tenant** is the data-isolation boundary: one organisation that runs its
   lending on nPOS (Northern Arc, or a bank). Every row in every service
   carries `tenant_id`.
2. Each tenant has a **home lender** (its own regulated entity).
   Originators and other lenders it works with are **partners** inside that
   tenant.
3. The tenant is resolved from the authenticated principal (a Keycloak realm
   or organisation claim for users; the API client for partners) and held in a
   request-scoped tenant context. A shared library applies it to every
   repository query and rejects queries without it.
4. **Exception for co-lending:** an arrangement is owned by the originating
   lender's tenant. When the co-lender is another tenant on the same
   installation, that tenant gets read and approve access to that arrangement
   only, through an explicit party link, never through a general cross-tenant
   query.
5. An **on-premise installation** is the same software with one tenant. No
   code paths differ by deployment model; only configuration does.
6. Isolation is logical (shared schema, tenant column) in the hosted
   installation. A tenant needing physical separation gets its own
   installation.

## Alternatives considered

- **Schema per tenant on a shared database.** Stronger isolation, but
  migrations multiply by tenant count and cross-tenant arrangements become
  awkward. Banks needing that level of isolation take an on-premise install instead.
- **Database per tenant per service.** Operationally heavy at 25 tenants ×
  15 services.

## Consequences

- Tenant isolation must be tested explicitly (automated cross-tenant access
  tests per API, and penetration testing).
- Open question Q1 (how bank tenants onboard their own originators) and Q2
  (one bank, many originating lenders) may refine the party-link rule.
