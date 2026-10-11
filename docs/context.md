# Context: what nPOS is and why we are rebuilding it

## What nPOS does

nPOS is Northern Arc's cloud-based, API-enabled platform for partnership
lending and co-lending. It connects **originators** (fintechs, NBFCs, MFIs,
marketplaces, payment orchestrators such as Juspay for Flipkart) with
**lenders** (Northern Arc itself, and banks such as South Indian Bank, DCB Bank
and Karnataka Bank). Loans are processed straight through, usually without
manual steps.

It plays two roles:

1. **Northern Arc's own partnership-lending engine.** Northern Arc lends, and
   originators push loans in.
2. **A product sold to banks.** A bank runs its own co-lending with
   originators, either hosted by Northern Arc or installed in the bank's own
   environment (South Indian Bank does this).

So the platform must be **multi-tenant** and deployable both hosted and on a
bank's premises, from **one codebase**.

## Business models

| Model | What happens |
|---|---|
| Partnership lending | The originator sources the loan, Northern Arc funds 100%, often backed by a default loss guarantee (DLG) from the partner |
| Co-lending / co-origination | Two regulated lenders fund each loan by ratio (for example 80:20). Both lenders' credit policies must pass. Disbursement and every repayment are split |
| Business correspondent | The partner acts as the lender's agent. The loan is fully on the lender's book and the partner earns a fee |
| Direct assignment / pool buyout | A lender buys a pool of existing loans. Batch processing with monthly cash-flow transfers |

## The loan flow

intake → dedupe and KYC → bureau and score → business rules (BRE) → co-lender
allocation → offer and KFS → e-sign and e-stamp → mandate → disbursement →
boarding into the LMS or core banking system → collections apportionment →
reconciliation

The steps up to the decision are synchronous and must be fast. Everything after
is asynchronous and event-driven.

## The configuration matrix

Every business decision depends on **tenant × originator × product × business
model × channel**. The platform must treat each combination as configuration,
not as code written for one partner.

## What discovery found (meeting with Vignesh, 05-10-2026)

| # | Finding | Consequence |
|---|---|---|
| O1 | Business rules are hand-written Python files, one per partner, even when the rules are identical. A reusable UI-driven rule engine was designed but abandoned because its UI was hard to use | Rules take at least a week per partner and cause most errors |
| O2 | Workflow stages and Java disbursement classes are also copied per partner | Isolation through duplication; every partner adds code |
| O3 | Shared files and shared tables still break other partners | Regressions reach live partners and take about 2 days to fix |
| O4 | 20+ services run on one VM; every release takes all partners offline | A single point of failure, and downtime on every release |
| O5 | Knowledge sits with two people; no documentation | Key-person risk |
| O6 | Requirements change after the first BRD; developers copy the previous partner's configuration | Rework on every onboarding |
| O7 | No unit tests; QA comes after the developer; no post-mortems | Low release confidence |
| O8 | Pre-production is not used; UAT goes straight to production | Data-format surprises in production |
| O9 | The platform is asynchronous, but Flipkart wants an answer within 10–15 s and polls every 1–2 s | Fragile integration with the most demanding partner |
| O10 | At least two installations (Northern Arc's and South Indian Bank's) | Releases must work across installations |
| O11 | Volumes are modest today (FatakPay about 700–800 loans a day) | Changeability and safety matter more than scale right now |

End-to-end partner onboarding takes **about 3 weeks**. The target is
**about 1 week, mostly business-led**, with no code or SQL written per
partner. Vignesh's goal: "80% by the business team, 20% developer support".

## What this repository does about it

The target design removes the root causes:

- **Partner set-up as versioned configuration** with maker-checker approval and
  safe promotion between environments (Module 1, Partner and Program
  Management).
- **Reusable, versioned, testable rule sets** instead of Python per partner
  (Module 2, Credit Policy and Rules Engine).
- **Shared journey stages driven by configuration** (Module 4, Journey
  Orchestrator).
- **Kubernetes deployment with rolling, zero-downtime releases**, and the same
  Helm charts for hosted and bank installations.

## Sources

- SRS Overview, Use Case Briefs, nPOS Requirements and Architecture Deep Dive
  (Drive: Software Requirement Specifications)
- UC-01.01 to UC-01.07 detailed specifications and NFR UP-01 (Drive: UP-01)
- Northern Arc meeting minutes 05-10-2026
- Public: <https://www.northernarc.com/npos>
