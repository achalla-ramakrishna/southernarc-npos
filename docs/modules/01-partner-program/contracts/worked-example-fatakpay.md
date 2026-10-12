# Worked example: onboarding FatakPay

This walks through onboarding a partnership-lending originator end to end
using only the contracts in this folder. It checks that the APIs, events and
approval steps fit together, and shows what replaces today's per-partner code,
SQL release document and downtime.

> **Illustrative data.** Identifiers, amounts, people and terms are
> placeholders, not FatakPay's real details or agreement. FatakPay is used
> because discovery gave real context: onboarding took about three weeks, it hit
> a rate limit on day two, and the limit was raised from 100 to 300.

## Cast

| Person | Role | Tenant |
|---|---|---|
| Priya | Partner manager (maker) | Northern Arc |
| Arjun | Compliance officer | Northern Arc |
| Meera | Credit policy manager | Northern Arc |
| Ravi | Finance executive | Northern Arc |
| Sam | Platform administrator | Northern Arc |
| FatakPay tech lead | Partner technical contact | (external) |

Starting state: tenant `NACL` exists. An approved personal-loan program for
another partner exists (`PRG-000031` v4), which Priya will clone.

## Overview

```mermaid
sequenceDiagram
  autonumber
  actor Priya as Priya (Partner mgr)
  actor Arjun as Arjun (Compliance)
  actor Meera as Meera (Credit policy)
  actor Ravi as Ravi (Finance)
  actor Sam as Sam (Platform admin)
  participant PC as partner-config-service
  participant K as Kafka
  participant FP as FatakPay

  Priya->>PC: duplicate-check, POST /partners, upload docs, PUT profile v1
  Priya->>PC: POST /change-requests/CR-000101/submission
  Arjun->>PC: POST decisions APPROVE
  PC->>K: partner.v1 PARTNER_APPROVED (PTR-000045)
  PC->>FP: one-time link for sandbox credentials
  FP->>PC: certificate, IPs, webhook URL
  PC->>K: api-client.v1 API_CLIENT_ISSUED (SANDBOX)
  Priya->>PC: limit set + DLG drafts, submit
  Ravi->>PC: record + verify bank guarantee
  Arjun->>PC: APPROVE
  PC->>K: limit-set.v1 / dlg-cover.v1 ACTIVATED
  Priya->>PC: POST programs (cloneFrom PRG-000031 v4), PUT changes, validate, submit
  Meera->>PC: link rule set, APPROVE (effective 20-Oct 00:00 IST)
  PC->>K: program.v1 PROGRAM_VERSION_SCHEDULED
  Priya->>PC: commercials draft, submit
  Ravi->>PC: APPROVE
  Sam->>PC: attest contract tests passed; request PRODUCTION credentials
  FP->>PC: production certificate, IPs, webhook URL
  PC->>K: api-client.v1 API_CLIENT_ISSUED (PRODUCTION)
  PC->>K: partner.v1 PARTNER_WENT_LIVE
  Note over PC,K: 20-Oct 00:00 IST, scheduler
  PC->>K: program.v1 PROGRAM_VERSION_ACTIVATED (actor SYSTEM)
```

## Step by step

### 1. Partner onboarding (UC-01.01)

**1a. Duplicate check** (step 6, ≤ 1 s)

```http
GET /admin/partner-config/v1/partners/duplicate-check?pan=AAACX1234K&gstin=29AAACX1234K1Z5
→ 200 { "matches": [] }
```

**1b. Create the draft partner**

```http
POST /admin/partner-config/v1/partners
Idempotency-Key: 0e1f6c2a-9a4e-4b1e-9d1e-2b7f6d0c8a11

{ "partnerType": "FINTECH_LSP", "legalName": "Example Fintech Pvt Ltd",
  "pan": "AAACX1234K", "gstin": "29AAACX1234K1Z5", "cin": "U65999KA2019PTC123456" }

→ 201  ETag: "p1-1"
{ "aggregateId": "01928f3e-…", "version": 1, "changeRequestId": "CR-000101" }
```

**1c. Upload documents.** For each checklist document, call
`POST /partners/{id}/document-uploads`, upload the file to the returned
`uploadUrl`, and keep the `DocumentRef`.

**1d. Fill in the profile** with `PUT /partners/{id}/profile-versions/1` and
`If-Match: "p1-1"`. Priya saves several times over two days (alt. flow A2);
each save returns a new ETag.

**1e. Validate before submitting.** The first attempt catches a missing item:

```json
{ "valid": false, "violations": [
  { "code": "GRIEVANCE_OFFICER_REQUIRED", "rule": "BR-01.01-07",
    "field": "/content/contacts/grievanceOfficer",
    "message": "Lending service providers must name a grievance redressal officer with phone and email. Add the grievance officer contact." } ] }
```

Priya adds the contact. Validation passes.

**1f. Submit.** `POST /change-requests/CR-000101/submission`. The risk rating
is MEDIUM, so the approval matrix produces one step: `COMPLIANCE_OFFICER`.

**1g. Arjun approves.** `POST /change-requests/CR-000101/decisions` with
`{ "stepId": "…", "decision": "APPROVE", "comment": "DD complete; screening clear." }`.
Had Priya tried this, she would get `403 MAKER_CANNOT_APPROVE`.

On approval, in one transaction:
- the partner gets `PTR-000045` and status `APPROVED_NOT_LIVE`,
- profile v1 becomes `ACTIVE`,
- an audit record is chained,
- the outbox gets a `PartnerSnapshot` and a sandbox credential request is created (UC-01.05 «include»).

Message on `npos.partner-config.partner.v1` (key = partner ID):

```json
{
  "schemaVersion": "1",
  "tenantId": "NACL",
  "aggregateId": "01928f3e-…",
  "revision": 3,
  "publishedAt": "2026-10-13T11:42:05+05:30",
  "cause": { "changeRequestId": "CR-000101", "actor": "arjun" },
  "trigger": "PARTNER_APPROVED",
  "partner": { "id": "01928f3e-…", "partnerCode": "PTR-000045", "partnerType": "FINTECH_LSP",
               "status": "APPROVED_NOT_LIVE", "riskRating": "MEDIUM", "activeProfileVersion": 1 },
  "activeProfile": { "version": 1, "versionId": "01928f41-…", "legalName": "Example Fintech Pvt Ltd",
                     "businessModels": ["PARTNERSHIP_LENDING"], "channels": ["API"],
                     "isLendingServiceProvider": true, "rbiRegulated": false },
  "programIds": []
}
```

### 2. Sandbox credentials (UC-01.05)

FatakPay's tech lead opens the one-time link and posts their certificate, IPs
and webhook URL to `/partner/v1/credential-requests/{token}`. The service
creates the Keycloak client, sends a signed test webhook, and delivers the
secret through a separate one-time link. `ApiClientSnapshot` with trigger
`API_CLIENT_ISSUED` goes out, and the gateway starts accepting FatakPay's sandbox calls.
No secret appears in any event, log or response (ADR-0009).

### 3. Limits and DLG (UC-01.04)

- `POST /partners/PTR-000045/limit-sets`: overall ₹50 crore, daily ₹2 crore,
  monthly ₹40 crore, per borrower ₹1 lakh, alerts at 80% and 90%.
- `POST /partners/PTR-000045/dlg-covers`: bank guarantee, 5% of the covered
  portfolio. The validator checks this against the regulatory DLG cap held in
  reference data. A higher value would return `DLG_ABOVE_REGULATORY_CAP` with
  the cap in the message.
- Ravi records the bank guarantee (`POST /dlg-covers/{id}/instruments`) and
  verifies it (`POST /dlg-instruments/{id}/verification`). This is the Finance
  step of the change request. Arjun then approves.
- `LimitSetSnapshot` (`LIMIT_SET_VERSION_ACTIVATED`) and `DlgSnapshot`
  (`DLG_COVER_ACTIVATED`) are published. Module 7 will enforce them; until it
  exists they are recorded but not enforced (ADR-0008).

### 4. The program, by cloning (UC-01.02)

Today this is where a developer copies the previous partner's Python rule file
and workflow stages. Here:

```http
POST /admin/partner-config/v1/partners/PTR-000045/programs
{ "name": "FatakPay Personal Loan – App", "businessModel": "PARTNERSHIP_LENDING",
  "product": "PERSONAL_LOAN", "channel": "API",
  "cloneFrom": { "programId": "PRG-000031", "version": 4 } }
→ 201 { "aggregateId": "01928f5a-…", "version": 1, "changeRequestId": "CR-000117" }
```

The program gets its business ID `PRG-000052` on approval. Priya changes only what differs: amount ₹5,000–₹1,00,000, tenures 3–12
months, rate band 2400–3000 bps, processing fee 2%, and links the limit set and
DLG cover. `POST …/versions/1/validation` returns the sample KFS and schedule
references for review.

On submission the matrix assigns `CREDIT_POLICY_MANAGER`. Meera links the
**existing** published rule set (`{ "ruleSetId": "RS-PL-STD", "version": 7 }`),
the same one another partner already uses. This is the "same rules, still a
week" problem from discovery, solved by reference rather than copying. She sets
`effectiveFrom` to 20-Oct 00:00 IST and approves.

Because the effective time is in the future, the program version is
`SCHEDULED`, and `ProgramSnapshot` is published with
`trigger: PROGRAM_VERSION_SCHEDULED`, `activeVersion: null` and v1 in
`scheduledVersions`. Every consumer now holds v1 and switches it on locally at
the effective time, even if Module 1 is down then (ADR-0007).

### 5. Commercials (UC-01.06)

Sourcing fee 1.5% of disbursed amount, payable to FatakPay, with a clawback
of 100% on cooling-off cancellation, monthly self-billing. Ravi approves.
`CommercialSnapshot` goes to settlement (Module 11 later).

### 6. Go-live readiness (BR-01.01-06)

`GET /partners/PTR-000045/readiness` shows two pending items:

| Check | Status |
|---|---|
| PARTNER_APPROVED | PASSED |
| PROGRAM_APPROVED_WITH_RULE_SET | PASSED |
| DLG_AND_LIMITS_ACTIVE | PASSED |
| COLENDING_ARRANGEMENT_ACTIVE | NOT_APPLICABLE |
| CONTRACT_TESTS_PASSED | **PENDING** |
| PRODUCTION_CREDENTIALS_ISSUED | **PENDING** |
| DISCLOSURE_PUBLISHED | PASSED (Compliance attested the website update) |
| DUE_DILIGENCE_VALID | PASSED |

- Sam attests the sandbox contract-test report (`POST …/readiness/attestations`
  with `CONTRACT_TESTS_PASSED`).
- Sam requests PRODUCTION credentials. This is now allowed because every other
  check has passed (BR-01.05-04). FatakPay submits production certificate,
  IPs and webhook URL, and `API_CLIENT_ISSUED (PRODUCTION)` is published.
- All checks pass, so the partner becomes `LIVE` automatically.
  `PartnerSnapshot` with `PARTNER_WENT_LIVE` is published.

At 20-Oct 00:00 IST the scheduler activates program v1. `ProgramSnapshot`
with `PROGRAM_VERSION_ACTIVATED` (actor `SYSTEM`) is published, and intake
accepts FatakPay applications. Each application records
`programVersionId`, `limitSetVersionId` and `commercialVersionId`.

**Nothing in this walkthrough involved a code change, a SQL script, a
deployment or downtime for other partners.**

## Day two: changes after go-live

### A. Raise the rate limit (what happened in discovery)

FatakPay hits its rate limit. Sam raises it:

```http
PATCH /admin/partner-config/v1/api-clients/{id}
Content-Type: application/merge-patch+json
{ "rateLimits": { "perSecond": 5, "perDay": 300000 } }
```

`ApiClientSnapshot` (`API_CLIENT_UPDATED`) reaches the gateway within seconds.
No release is needed. The contract states the units explicitly (per second
and per day), which removes the "100 per hour or per minute?" ambiguity
discovery ran into (open question Q7).

### B. Temporary cap for a sale weekend

Priya creates limit set v2 with a temporary daily cap of ₹6 crore from Friday
00:00 to Monday 00:00 IST (`endsAt` is mandatory, BR-01.04-05). It is an
increase, so the full approval chain applies. Once approved it is `SCHEDULED`.
Module 7 applies the higher cap at the start and drops back automatically at
the end.

### C. Emergency suspension

Fraud is suspected. Arjun posts a suspension order with `emergency: true`
(only Compliance may). In one transaction:
- the partner becomes `SUSPENDED` for new applications,
- a `PriorityControl` message `BLOCK_PARTNER` goes on the priority topic, and
  the gateway and intake block FatakPay's application calls within seconds,
- FatakPay's credentials become `RESTRICTED`, so status and servicing calls
  still work,
- the change request records that approval is still owed.

The full `PartnerSnapshot` (`PARTNER_SUSPENDED`) follows. Reinstating later is
a normal change request, and the previous credentials and status return.

## What this example showed

| Today (discovery) | With these contracts |
|---|---|
| About 3 weeks end to end | Elapsed time is set by document collection and approvals, not development |
| Python rule file per partner | Link an existing published rule set |
| Workflow stages copied per partner | Clone a program version, change parameters |
| SQL release document approved by other partners' owners | Change requests approved by the right roles; other partners untouched |
| Release with downtime for all partners | Effective-dated activation; no deployment |
| Rate limit changed with ambiguous units | Explicit `perSecond` / `perDay`, applied in seconds |

## Gaps this example exposed

| # | Gap | Proposed resolution |
|---|---|---|
| G-1 | Contract tests are attested manually until a partner test harness exists | Keep attestation; build a sandbox contract-test runner with Module 3 |
| G-2 | Disclosure publication is attested manually until Module 14 | Keep attestation; consume a `DisclosurePublished` event later |
| G-3 | No API yet to list which partners use a rule set (impact of a rule change) | Add `GET /rule-set-usages?ruleSetId=` to the admin API with Module 2 |
