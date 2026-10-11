# Module 1: Partner and Program Management (scope)

Step 1 of the module. Status: **draft for review**.

## 1. Purpose

Module 1 is the single source of truth for **who may originate and fund loans
through nPOS, for which product and business model, and on which terms**. It
replaces today's per-partner Python and Java files, duplicated workflow stages
and manual SQL release documents with versioned, approved configuration.

Every other service reads its configuration: intake checks the partner is live
for the program, decisioning finds the linked rule set, allocation uses the
co-lending arrangement, disbursement checks limits and DLG, settlement uses the
commercials.

## 2. Use cases in scope

| Use case | Summary | Primary actor | Approver(s) |
|---|---|---|---|
| UC-01.01 Onboard originator partner | Capture legal, regulatory, due-diligence and agreement details; approve the partner to *Approved – not live* | A06 Partner manager | A10 Compliance officer (+ Head of Compliance for high risk) |
| UC-01.02 Configure product program | Amount, tenure, pricing, fees, journey options, documents, templates, links to policy, arrangement and limits; versioned with effective dates | A06 Partner manager | A05 Credit policy manager (+ A04 for policy exceptions) |
| UC-01.03 Configure co-lending arrangement | Shares, retention, rates, blended-rate method, fee sharing, policies, limits, escrow, co-lender codes; verified with escrow bank and co-lender core | A06 Partner manager | A13 Co-lender user |
| UC-01.04 Configure DLG and exposure limits | DLG terms and instrument; partner, program, daily, monthly and per-borrower limits; temporary caps | A06 Partner manager | A08 Finance (instrument), A10 Compliance |
| UC-01.05 Manage partner API credentials | Issue, rotate and revoke OAuth clients, mTLS certificates, IP lists, scopes, rate limits, webhook URL and signing key | A12 Platform administrator | Go-live checks for production |
| UC-01.06 Configure partner commercials | Sourcing and servicing fees, subvention, fee sharing, clawbacks, tax, settlement terms, ERP codes | A06 Partner manager | A08 Finance |
| UC-01.07 Suspend or offboard partner | Scoped suspension, emergency suspension, reinstatement, offboarding run-off | A06 Partner manager / A10 | A10 Compliance |
| UC-13.02 Onboard co-lender tenant | Set up a bank as a tenant: data separation, users, integrations, deployment model | A12 Platform administrator | — |

Supporting capabilities the module also needs (no separate use case in the SRS):

- **Reference data**: partner types, document checklists per type, business
  models, product master, charge types, reason codes, approval matrix.
- **Regulatory parameters**: DLG cap, minimum co-lending retention, cooling-off
  minimum, interest rate policy bands per product. Versioned, held centrally,
  with an impact report on change (NFR-UP01-R07).
- **Go-live readiness**: the checklist in BR-01.01-06, evaluated by the module.
- **Configuration packages**: export, compare and import approved
  configuration between environments (NFR-UP01-CF04).
- **Point-in-time view**: the configuration in force at any moment
  (NFR-UP01-AU04).

## 3. Out of scope (owned elsewhere)

| Concern | Owner | What Module 1 holds instead |
|---|---|---|
| Credit rules, scorecards, simulation | Module 2 | A reference to a published rule-set version |
| Journey step definitions and execution | Module 4 | A reference to a journey template plus the program's journey options |
| Real-time limit utilisation and exposure locks | Module 7 | Limit **definitions** only (see ADR-0008) |
| DLG invocation and partner settlement runs | Module 11 | DLG terms and commercial rules |
| Webhook delivery | Module 13 | Webhook URL and signing key reference |
| Lending disclosures on the website | Module 14 (UC-12.07) | The disclosure flag and a readiness check |
| Long-term document archive | DMS | Document references only (never the bytes) |
| Partner invoicing | Finance ERP | ERP vendor and customer codes |

## 4. Actors

Human: A04 Credit approver, A05 Credit policy manager, A06 Partner manager,
A08 Finance executive, A10 Compliance officer (and Head of Compliance), A12
Platform administrator, A13 Co-lender user.

Systems: S01/S02 partner systems (submit certificates and webhook URLs), S03
co-lender core systems (verification message), S09 escrow bank (account
confirmation), S16 DMS, S17 identity provider and API gateway (Keycloak and
gateway), S22 finance ERP.

## 5. Quality targets that shape the design

From NFR UP-01. These targets drive the decisions in the ADRs.

| Target | Value | Design consequence |
|---|---|---|
| Config read by the loan journey | ≤ 10 ms p99, 5,000 reads/s | Consumers read a local cache, never Module 1 directly (ADR-0007) |
| Approved change used by new applications | ≤ 60 s after effective time | Events plus effective-dated versions (ADR-0004, ADR-0007) |
| Suspension or revocation takes effect | ≤ 60 s from approval | Priority invalidation event; gateway enforces too |
| Survives a config store outage | ≥ 4 hours on cached config | Consumers keep a persisted snapshot |
| Rollback to previous version | ≤ 5 minutes, with maker-checker | Immutable versions; rollback is a new approved change |
| Maker ≠ checker on every change | Enforced server-side | Generic change-request model (ADR-0005) |
| Tenant isolation | Zero cross-tenant reads | Tenant filter enforced in the shared library (ADR-0003) |
| Tamper-evident audit | Append-only, hash-chained | Audit log owned by the module, chained per record |
| Every loan records the versions it used | 100% | Version IDs carried on every config read |
| New partner on an existing product | Live within 10 working days, no code release | Clone, configuration packages, readiness checks |
| Volume | 200 partners, 25 tenants, 1,000 programs × 20 versions; 100 concurrent users | One service and one schema are enough (ADR-0006) |

## 6. Dependencies

- **Module 0** (gateway, Keycloak, shared libraries) must exist in a minimal
  form first.
- **Module 2** is needed for a program to go live (BR-01.02-06). Until it
  exists, the rule-set link is a validated reference to an external ID.
- **DMS**: an S3-compatible document service. MinIO in development.
- **Finance ERP, escrow bank, co-lender core**: mocked behind adapters until
  real endpoints are available.

## 7. Definition of done for Module 1

1. A new partner with an existing product shape can be onboarded, configured,
   approved and made live **entirely from the UI**, with no SQL and no restart.
2. Cloning an existing partner's programs produces a ready-to-review draft in
   minutes.
3. Every change goes through maker-checker. Every version is effective-dated
   and immutable, and the full history is auditable.
4. Other services receive configuration changes within 60 s and keep working
   through a Module 1 outage.
5. Approved configuration can be exported from one environment and imported
   into another as a signed package, with a diff.
6. Seed data models FatakPay (partnership lending), Juspay (checkout EMI via
   orchestrator) and a South Indian Bank co-lending arrangement, covering the
   business models.

## 8. Open questions (to confirm with Northern Arc)

Carried from the use case specifications, plus questions raised by this design.

| # | Question | Affects |
|---|---|---|
| Q1 | How do bank tenants onboard their own originators: through UC-01.01 as-is, or a tenant-specific variant? | Tenancy model (ADR-0003) |
| Q2 | Can a bank be co-lender with several originating lenders under one arrangement? | Arrangement model |
| Q3 | Should PAN, CIN and GSTIN be verified via KYC services or format-checked only? | UC-01.01 step 6 |
| Q4 | Current regulatory values: DLG cap, minimum retention, cooling-off minimum | Regulatory parameters |
| Q5 | Interest rate policy bands per product; may partners price within a band? | Program pricing |
| Q6 | Who approves temporary limit increases for sale events? | Approval matrix |
| Q7 | Should draft programs be created at partner approval (UC-01.01 step 20)? | Onboarding flow |
| Q8 | Which API gateway and identity provider does Northern Arc use today; does South Indian Bank's installation use the same? | ADR-0009 |
| Q9 | What does a Northern Arc "workflow stage" contain today, so journey options in the program map onto it? | Program journey options, Module 4 |
