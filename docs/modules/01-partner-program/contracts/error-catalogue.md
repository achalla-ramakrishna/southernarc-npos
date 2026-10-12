# Module 1: error catalogue

Every error the partner-config APIs return has one stable `code` from this
list. Where a business rule is behind it, the `rule` field carries the rule
ID, so the UI, support staff and auditors can trace the error to the
requirement (NFR-UP01-U06).

Errors use RFC 9457 Problem Details. Validation returns **all** violations at
once in `violations[]`, each with its own code, rule and field (JSON Pointer).

```json
{
  "type": "https://errors.npos.example/partner-config/COLENDING_RETENTION_BELOW_MINIMUM",
  "title": "Business rule violated",
  "status": 422,
  "code": "VALIDATION_FAILED",
  "violations": [
    {
      "code": "COLENDING_RETENTION_BELOW_MINIMUM",
      "rule": "BR-01.03-01",
      "field": "/content/shares/0/shareBps",
      "message": "Originating lender share 5.00% is below the minimum retention of 10.00%. Increase the share to at least 10.00%."
    }
  ],
  "correlationId": "4bf92f3577b34da6a3ce929d0e0e4736"
}
```

Messages say **what is wrong and how to fix it**. The `message` text is
English. The UI may translate by `code`.

## Generic

| Code | HTTP | Rule | When |
|---|---|---|---|
| `MALFORMED_REQUEST` | 400 | — | Invalid JSON, wrong types, unknown enum on input |
| `UNAUTHENTICATED` | 401 | — | Missing or invalid token |
| `ROLE_NOT_ALLOWED` | 403 | NFR-UP01-S02 | Caller lacks the operation's role |
| `NOT_FOUND` | 404 | ADR-0003 | Resource does not exist **in the caller's tenant** |
| `INVALID_STATE_TRANSITION` | 409 | — | Action not allowed in the current status (for example editing an approved version) |
| `IDEMPOTENCY_KEY_REUSED` | 409 | — | Same Idempotency-Key with a different body |
| `PRECONDITION_FAILED` | 412 | — | If-Match ETag is stale |
| `VALIDATION_FAILED` | 422 | — | Wrapper for one or more violations below |
| `DEPENDENCY_UNAVAILABLE` | 503 | NFR-UP01-I01 | DMS, ERP, Keycloak or a bank system did not respond; retry with the same Idempotency-Key |

## Maker-checker and change requests

| Code | HTTP | Rule | When |
|---|---|---|---|
| `MAKER_CANNOT_APPROVE` | 403 | BR-01.01-03, NFR-UP01-S04 | The maker tries to decide a step of their own request |
| `APPROVER_ALREADY_DECIDED` | 403 | NFR-UP01-S04 | The same user tries to decide a second step of one request |
| `APPROVER_WRONG_TENANT` | 403 | ADR-0003 | The approver's tenant is not the step's tenant (for example a co-lender step) |
| `STEP_NOT_CURRENT` | 409 | — | Decision on a step that is not the pending one |
| `COMMENT_REQUIRED` | 422 | UC-01.01 A6, A7 | Return or reject without a comment |
| `EMERGENCY_NOT_ALLOWED` | 403 | UC-01.07 A1 | Emergency flag set by a non-Compliance user |
| `SCHEDULED_VERSION_ALREADY_EFFECTIVE` | 409 | NFR-UP01-CF07 | Cancelling a scheduled version after its effective time |
| `EFFECTIVE_FROM_IN_PAST` | 422 | — | Effective time earlier than now on submission |
| `EFFECTIVE_PERIOD_OVERLAP` | 422 | G9, BR-01.02-05 | Two versions of one aggregate would be in force at the same time |
| `APPLY_FAILED` | 500 | NFR-UP01-A05 | Approval could not be applied; nothing changed. Retried automatically |

## Partner (UC-01.01)

| Code | HTTP | Rule | When |
|---|---|---|---|
| `PARTNER_DUPLICATE_IDENTIFIER` | 409 | BR-01.01-01 | PAN, CIN/LLPIN or GSTIN already belongs to a partner; response lists the existing partner |
| `PARTNER_REJECTED_CANNOT_REOPEN` | 409 | BR-01.01-09 | Trying to resubmit a rejected partner instead of a new case |
| `PARTNER_PREDECESSOR_REQUIRED` | 422 | BR-01.01-09 | Re-onboarding a rejected entity without referencing the rejected case |
| `INVALID_PAN` / `INVALID_CIN` / `INVALID_LLPIN` / `INVALID_GSTIN` / `INVALID_PIN_CODE` | 422 | UC-01.01 step 6 | Format or checksum check failed |
| `MANDATORY_FIELD_MISSING` | 422 | BR-01.01-02 | A field required for the partner type is empty |
| `CHECKLIST_DOCUMENT_MISSING` | 422 | BR-01.01-02, E1 | A checklist document has no DMS reference |
| `REGULATED_LENDER_REQUIRED` | 422 | BR-01.01-04 | Co-lending or DA seller chosen for an unregulated partner |
| `CERTIFICATE_OF_REGISTRATION_REQUIRED` | 422 | BR-01.01-04 | Regulated lender without CoR details |
| `GRIEVANCE_OFFICER_REQUIRED` | 422 | BR-01.01-07 | LSP or DLA partner without grievance officer phone and email |
| `DATA_STORAGE_OUTSIDE_INDIA` | 422 | NFR-UP01-D04 | Data storage location is outside India |
| `AGREEMENT_DATES_INVALID` | 422 | UC-01.01 §8 | Agreement end is not after its effective date |
| `DUE_DILIGENCE_EXPIRED` | 422 | BR-01.01-08 | New program for a partner whose assessment has expired |
| `DOCUMENT_TYPE_NOT_ALLOWED` / `DOCUMENT_TOO_LARGE` | 422 | UC-01.01 §8 | Not PDF/JPG/PNG, or over 20 MB |

## Program (UC-01.02)

| Code | HTTP | Rule | When |
|---|---|---|---|
| `PROGRAM_NAME_NOT_UNIQUE` | 409 | UC-01.02 §8 | Name already used by another program of the partner |
| `BUSINESS_MODEL_NOT_APPROVED_FOR_PARTNER` | 422 | BR-01.02-07 | Model not in the partner's approved business models |
| `AMOUNT_RANGE_INVALID` / `TENURE_RANGE_INVALID` | 422 | G1 | min > max, or outside the product master |
| `RATE_OUTSIDE_POLICY` | 422 | BR-01.02-01 | Rate band or a risk-grade rate is outside the interest rate policy and not flagged as an exception |
| `RISK_GRADE_RATE_OUTSIDE_BAND` | 422 | UC-01.02 §8 | A grid rate is outside the program's own band |
| `CHARGE_NOT_IN_KFS` | 422 | BR-01.02-02 | A charge has no KFS line |
| `COOLING_OFF_BELOW_MINIMUM` | 422 | BR-01.02-03 | Cooling-off days below the regulatory minimum |
| `MERCHANT_DISBURSEMENT_NOT_ALLOWED` | 422 | BR-01.02-04 | Merchant payout or subvention on a non-purchase-finance product |
| `KYC_METHOD_REQUIRED` | 422 | UC-01.02 §8 | No KYC method selected |
| `LSP_FEE_AS_BORROWER_CHARGE` | 422 | BR-01.06-01, NFR-UP01-R05 | A fee due to an LSP is configured as a borrower charge |
| `RULE_SET_NOT_PUBLISHED` | 422 | BR-01.02-06 | Linked rule set version is not published in Module 2 |
| `ARRANGEMENT_NOT_ACTIVE` | 422 | UC-01.02 A4 | Co-lending program linked to an arrangement that is not ACTIVE |
| `LIMIT_SET_REQUIRED` | 422 | G7 | Agreement requires limits but none linked or active |
| `SAMPLE_KFS_FAILED` | 422 | UC-01.02 E1 | The sample KFS or schedule could not be generated; detail names the template field |
| `PROGRAM_RETIRED` | 409 | UC-01.02 A6 | Change to a retired program |

## Co-lending arrangement (UC-01.03)

| Code | HTTP | Rule | When |
|---|---|---|---|
| `COLENDING_SHARES_NOT_100` | 422 | C1 | Shares do not total 100% |
| `COLENDING_RETENTION_BELOW_MINIMUM` | 422 | BR-01.03-01 | A share is below the lender's minimum retention or the regulatory minimum |
| `COLENDING_LENDER_NOT_REGULATED` | 422 | C2 | A party is not an active RBI-regulated lender |
| `COLENDING_CAPS_INCONSISTENT` | 422 | C3, BR-01.03-06 | Not daily ≤ monthly ≤ total |
| `COLENDING_CHARGE_UNASSIGNED` | 422 | C4 | A KFS charge has no fee-sharing rule |
| `COLENDING_REVIEW_WINDOW_REQUIRED` | 422 | UC-01.03 §8 | Co-lender review model without a window |
| `COLENDING_VERIFICATION_PENDING` | 409 | C5, E1, E2 | Action needs an ACTIVE arrangement but escrow or core verification has not passed |

## DLG and limits (UC-01.04)

| Code | HTTP | Rule | When |
|---|---|---|---|
| `DLG_ABOVE_REGULATORY_CAP` | 422 | BR-01.04-01, NFR-UP01-R01 | DLG exceeds the cap; message shows the cap and the current cover |
| `DLG_FORM_NOT_ALLOWED` | 422 | BR-01.04-02 | Form other than cash, FD with lien, or BG |
| `DLG_INSTRUMENT_MISMATCH` | 422 | L2 | Instrument amount ≠ DLG amount, or expiry before DLG validity end |
| `DLG_LIEN_NOT_MARKED` | 422 | L2 | FD instrument without a marked lien |
| `DLG_INSTRUMENT_NOT_VERIFIED` | 409 | UC-01.04 E1 | Compliance approval attempted before Finance verification |
| `LIMITS_INCONSISTENT` | 422 | L3 | Program limits exceed the overall limit, or daily > monthly |
| `PER_BORROWER_ABOVE_PROGRAM_MAX` | 422 | L3 | Per-borrower maximum above the program maximum amount |
| `TEMPORARY_CAP_END_REQUIRED` | 422 | BR-01.04-05 | Temporary cap without an end time |

## Credentials (UC-01.05)

| Code | HTTP | Rule | When |
|---|---|---|---|
| `PRODUCTION_CREDENTIALS_NOT_READY` | 422 | BR-01.05-04 | Production requested before other go-live checks pass; lists unmet checks |
| `SCOPE_NOT_ALLOWED` | 422 | BR-01.05-01 | Scope outside the partner's approved programs |
| `RATE_LIMIT_ABOVE_PLATFORM_MAX` | 422 | UC-01.05 §8 | Rate limit above the per-partner maximum |
| `CERTIFICATE_INVALID` | 422 | UC-01.05 E3 | Expired, weak key (below RSA 2048), or validity over 1 year |
| `WEBHOOK_URL_NOT_HTTPS` | 422 | UC-01.05 §8 | Webhook URL is not HTTPS |
| `IP_ALLOW_LIST_REQUIRED` | 422 | UC-01.05 §8 | Production without an IP allow-list |
| `ROTATION_OVERLAP_TOO_LONG` | 422 | BR-01.05-03 | Overlap over 7 days |
| `CREDENTIAL_LINK_EXPIRED` | 410 | UC-01.05 E2 | One-time link expired or already used |

## Commercials (UC-01.06)

| Code | HTTP | Rule | When |
|---|---|---|---|
| `COMMERCIAL_ITEM_OVERLAP` | 422 | M1 | Two items of the same type overlap for a program and period |
| `COMMERCIAL_CLAUSE_REQUIRED` | 422 | BR-01.06-02 | A fee payable to the partner names no agreement clause |
| `ERP_CODES_MISSING` | 422 | UC-01.06 E1 | Submission without ERP vendor and customer codes |

## Suspension and offboarding (UC-01.07)

| Code | HTTP | Rule | When |
|---|---|---|---|
| `PARTNER_NOT_LIVE` | 409 | UC-01.07 §4 | Suspension of a partner that is not LIVE or SUSPENDED |
| `IN_FLIGHT_HANDLING_REQUIRED` | 422 | UC-01.07 step 4 | Suspend or offboard without choosing in-flight handling |
| `OFFBOARDING_ACTIVE_LOANS_REMAIN` | 409 | BR-01.07-02 | Trying to complete offboarding while loans are active |

## Packages (ADR-0010)

| Code | HTTP | Rule | When |
|---|---|---|---|
| `PACKAGE_SIGNATURE_INVALID` | 422 | ADR-0010 | Signature check failed |
| `PACKAGE_SCHEMA_UNSUPPORTED` | 422 | ADR-0010 | Package schema version not readable by this release |
| `PACKAGE_CONTAINS_ENVIRONMENT_VALUES` | 422 | ADR-0010 §3 | Credentials, endpoints or accounts found in the package |
| `PACKAGE_ALREADY_APPLIED` | 409 | ADR-0010 §4 | Same package applied before; nothing to do |

## Partner-facing errors (runtime, for later modules)

When other modules reject a partner's loan call because of Module 1
configuration, they return these codes to the partner. Defined here so every
module uses the same ones.

| Code | HTTP | Meaning for the partner |
|---|---|---|
| `PARTNER_SUSPENDED` | 403 | Your partnership is suspended for this program or channel; new applications are not accepted |
| `PROGRAM_NOT_AVAILABLE` | 422 | The program is not live, retired, or not enabled for this channel |
| `LIMIT_REACHED` | 422 | A partner, program or daily limit has been reached (UC-01.04 E3) |
| `CREDENTIALS_RESTRICTED` | 403 | Your credentials allow status and servicing calls only |
