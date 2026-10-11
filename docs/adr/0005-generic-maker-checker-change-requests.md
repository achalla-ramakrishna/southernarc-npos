# ADR-0005: Generic maker-checker change requests with a configurable approval matrix

- Status: Proposed
- Date: 2026-10-11
- Scope: Module 1

## Context

All seven UP-01 use cases follow the same shape: a maker drafts, submits, and
one or more checkers approve, return or reject. Only the approvers differ
(Compliance, Head of Compliance, Credit policy manager, Credit approver,
Finance, Co-lender user), and some depend on conditions (high-risk partner,
policy exception, limit increase vs decrease). Approval rules must be
configurable without a release (NFR-UP01-CF02). Maker ≠ checker must be
enforced server-side (NFR-UP01-S04).

## Decision

1. One **ChangeRequest** model for every change in the module: type, target
   aggregate, proposed content (a draft version or a status change), status,
   and an ordered list of **approval steps** with decisions.
2. Steps are generated at submission from the **approval matrix** (reference
   data): change type + conditions → ordered roles. The matrix is itself
   versioned and changed through a change request.
3. The service enforces: the maker cannot approve any step; one user cannot
   approve two steps of the same request; the approver holds the step's role
   **in the right tenant** (a co-lender user approves only their bank's
   arrangements).
4. Approval of the last step applies the change atomically: the target version
   is created and activated (or scheduled), the audit record is written, and
   the event is placed in the outbox, all in one transaction (NFR-UP01-A05).
5. **Emergency suspension** is a change type whose matrix entry is "apply
   immediately, approve after", only available to Compliance (UC-01.07 A1).
6. Work lists, ageing and SLA tracking (NFR-UP01-U03, O03) are built on
   change requests, so every type gets them.

## Alternatives considered

- **A BPMN engine (Camunda) for approvals.** Powerful, but heavy for linear
  approval chains, and adds a runtime dependency to a low-volume service.
  We may revisit this if approvals become non-linear.
- **Approval code per use case.** This repeats the per-partner duplication
  problem one level up.

## Consequences

- Adding a new configurable object later (for example insurance products)
  needs no new approval code.
- The approval matrix must be seeded and reviewed with Northern Arc compliance
  (open question on the approval matrix in UC-01.01).
