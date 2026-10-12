-- Partners (UC-01.01), identifiers, profile versions, suspensions (UC-01.07), go-live readiness.

CREATE TABLE partner (
    id                      BINARY(16)   NOT NULL,
    tenant_id               BINARY(16)   NOT NULL,
    partner_code            VARCHAR(16)  NULL,       -- PTR-nnnnnn, assigned on approval
    partner_type            VARCHAR(32)  NOT NULL,
    display_name            VARCHAR(200) NOT NULL,
    status                  VARCHAR(24)  NOT NULL,
    risk_rating             VARCHAR(8)   NULL,
    active_profile_version  INT          NULL,
    latest_profile_version  INT          NOT NULL,
    rejected_predecessor_id BINARY(16)   NULL,
    snapshot_revision       BIGINT       NOT NULL DEFAULT 0,
    row_version             INT          NOT NULL DEFAULT 0,
    created_by              VARCHAR(64)  NOT NULL,
    created_at              DATETIME(6)  NOT NULL,
    updated_by              VARCHAR(64)  NOT NULL,
    updated_at              DATETIME(6)  NOT NULL,
    CONSTRAINT pk_partner PRIMARY KEY (id),
    CONSTRAINT uk_partner_code UNIQUE (partner_code),
    CONSTRAINT uk_partner_tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_partner_tenant FOREIGN KEY (tenant_id) REFERENCES tenant (id),
    CONSTRAINT fk_partner_predecessor FOREIGN KEY (tenant_id, rejected_predecessor_id) REFERENCES partner (tenant_id, id),
    CONSTRAINT ck_partner_type CHECK (partner_type IN (
        'NBFC', 'BANK', 'FINTECH_LSP', 'MFI', 'BUSINESS_CORRESPONDENT', 'MERCHANT_MARKETPLACE',
        'PAYMENT_ORCHESTRATOR', 'DEALER')),
    CONSTRAINT ck_partner_status CHECK (status IN (
        'DRAFT', 'PENDING_APPROVAL', 'RETURNED', 'REJECTED', 'APPROVED_NOT_LIVE', 'LIVE', 'SUSPENDED',
        'OFFBOARDING_RUN_OFF', 'OFFBOARDED', 'CLOSED')),
    CONSTRAINT ck_partner_risk CHECK (risk_rating IS NULL OR risk_rating IN ('LOW', 'MEDIUM', 'HIGH')),
    -- A partner past approval always has a business ID.
    CONSTRAINT ck_partner_code_after_approval CHECK (
        status IN ('DRAFT', 'PENDING_APPROVAL', 'RETURNED', 'REJECTED', 'CLOSED') OR partner_code IS NOT NULL),
    INDEX ix_partner_status (tenant_id, status),
    INDEX ix_partner_name (tenant_id, display_name)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- One partner per legal entity (BR-01.01-01). When a partner is rejected or its draft is closed, the
-- service sets released_at so the entity can be onboarded again as a new case (BR-01.01-09).
CREATE TABLE partner_identifier (
    id           BINARY(16)  NOT NULL,
    tenant_id    BINARY(16)  NOT NULL,
    partner_id   BINARY(16)  NOT NULL,
    id_type      VARCHAR(8)  NOT NULL,
    id_value     VARCHAR(21) NOT NULL,
    released_at  DATETIME(6) NULL,
    active_value VARCHAR(21) GENERATED ALWAYS AS (CASE WHEN released_at IS NULL THEN id_value END) STORED,
    CONSTRAINT pk_partner_identifier PRIMARY KEY (id),
    CONSTRAINT uk_partner_identifier_active UNIQUE (tenant_id, id_type, active_value),
    CONSTRAINT fk_partner_identifier_partner FOREIGN KEY (tenant_id, partner_id) REFERENCES partner (tenant_id, id),
    CONSTRAINT ck_partner_identifier_type CHECK (id_type IN ('PAN', 'CIN', 'LLPIN', 'GSTIN')),
    INDEX ix_partner_identifier_lookup (tenant_id, id_type, id_value),
    INDEX ix_partner_identifier_partner (partner_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE partner_profile_version (
    id                     BINARY(16)  NOT NULL,
    tenant_id              BINARY(16)  NOT NULL,
    partner_id             BINARY(16)  NOT NULL,
    version                INT         NOT NULL,
    status                 VARCHAR(24) NOT NULL,
    effective_from         DATETIME(6) NULL,
    effective_to           DATETIME(6) NULL,
    content                JSON        NOT NULL,
    content_schema_version SMALLINT    NOT NULL DEFAULT 1,
    change_request_id      BINARY(16)  NOT NULL,
    copied_from_version    INT         NULL,
    approved_at            DATETIME(6) NULL,
    row_version            INT         NOT NULL DEFAULT 0,
    created_by             VARCHAR(64) NOT NULL,
    created_at             DATETIME(6) NOT NULL,
    updated_by             VARCHAR(64) NOT NULL,
    updated_at             DATETIME(6) NOT NULL,
    risk_rating            VARCHAR(8)  GENERATED ALWAYS AS (content->>'$.dueDiligence.riskRating') STORED,
    active_parent_id       BINARY(16)  GENERATED ALWAYS AS (CASE WHEN status = 'ACTIVE' THEN partner_id END) STORED,
    CONSTRAINT pk_partner_profile_version PRIMARY KEY (id),
    CONSTRAINT uk_partner_profile_version UNIQUE (partner_id, version),
    CONSTRAINT uk_partner_profile_active UNIQUE (active_parent_id),
    CONSTRAINT fk_partner_profile_partner FOREIGN KEY (tenant_id, partner_id) REFERENCES partner (tenant_id, id),
    CONSTRAINT fk_partner_profile_cr FOREIGN KEY (tenant_id, change_request_id) REFERENCES change_request (tenant_id, id),
    CONSTRAINT ck_partner_profile_status CHECK (status IN (
        'DRAFT', 'PENDING_APPROVAL', 'RETURNED', 'REJECTED', 'SCHEDULED', 'ACTIVE', 'SUPERSEDED', 'RETIRED', 'CANCELLED')),
    CONSTRAINT ck_partner_profile_period CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT ck_partner_profile_content CHECK (JSON_TYPE(content) = 'OBJECT'),
    INDEX ix_partner_profile_due (status, effective_from),
    INDEX ix_partner_profile_cr (change_request_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE suspension_order (
    id                 BINARY(16)   NOT NULL,
    tenant_id          BINARY(16)   NOT NULL,
    partner_id         BINARY(16)   NOT NULL,
    change_request_id  BINARY(16)   NOT NULL,
    action             VARCHAR(16)  NOT NULL,
    scope_type         VARCHAR(16)  NOT NULL,
    scope_values       JSON         NOT NULL,
    reason_code        VARCHAR(24)  NOT NULL,
    description        VARCHAR(2000) NOT NULL,
    effective_mode     VARCHAR(16)  NOT NULL,
    effective_at       DATETIME(6)  NULL,
    in_flight_handling VARCHAR(24)  NULL,
    emergency          BOOLEAN      NOT NULL DEFAULT FALSE,
    created_by         VARCHAR(64)  NOT NULL,
    created_at         DATETIME(6)  NOT NULL,
    CONSTRAINT pk_suspension_order PRIMARY KEY (id),
    CONSTRAINT uk_suspension_order_tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_suspension_order_partner FOREIGN KEY (tenant_id, partner_id) REFERENCES partner (tenant_id, id),
    CONSTRAINT fk_suspension_order_cr FOREIGN KEY (tenant_id, change_request_id) REFERENCES change_request (tenant_id, id),
    CONSTRAINT ck_suspension_order_action CHECK (action IN ('SUSPEND', 'REINSTATE', 'OFFBOARD')),
    CONSTRAINT ck_suspension_order_scope CHECK (scope_type IN ('PARTNER', 'PROGRAM', 'PRODUCT', 'CHANNEL')),
    CONSTRAINT ck_suspension_order_offboard_whole CHECK (action <> 'OFFBOARD' OR scope_type = 'PARTNER'),
    CONSTRAINT ck_suspension_order_reason CHECK (reason_code IN (
        'RISK_BREACH', 'DLG_EXHAUSTED', 'FRAUD', 'REGULATORY_ACTION', 'CONTRACT_END', 'OTHER')),
    CONSTRAINT ck_suspension_order_mode CHECK (effective_mode IN ('IMMEDIATE', 'SCHEDULED')),
    CONSTRAINT ck_suspension_order_when CHECK (effective_mode = 'IMMEDIATE' OR effective_at IS NOT NULL),
    CONSTRAINT ck_suspension_order_in_flight CHECK (
        action = 'REINSTATE' OR in_flight_handling IN ('COMPLETE_SANCTIONED', 'CANCEL_UNDISBURSED'))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Suspensions currently or previously in force (scoped). lifted_at is set on reinstatement.
CREATE TABLE partner_suspension (
    id                  BINARY(16)  NOT NULL,
    tenant_id           BINARY(16)  NOT NULL,
    partner_id          BINARY(16)  NOT NULL,
    suspension_order_id BINARY(16)  NOT NULL,
    scope_type          VARCHAR(16) NOT NULL,
    scope_values        JSON        NOT NULL,
    reason_code         VARCHAR(24) NOT NULL,
    effective_from      DATETIME(6) NOT NULL,
    lifted_at           DATETIME(6) NULL,
    lifted_by_order_id  BINARY(16)  NULL,
    CONSTRAINT pk_partner_suspension PRIMARY KEY (id),
    CONSTRAINT fk_partner_suspension_partner FOREIGN KEY (tenant_id, partner_id) REFERENCES partner (tenant_id, id),
    CONSTRAINT fk_partner_suspension_order FOREIGN KEY (tenant_id, suspension_order_id) REFERENCES suspension_order (tenant_id, id),
    CONSTRAINT ck_partner_suspension_lift CHECK (lifted_at IS NULL OR lifted_at >= effective_from),
    INDEX ix_partner_suspension_active (tenant_id, partner_id, lifted_at)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Go-live readiness per partner (BR-01.01-06). One row per check code.
CREATE TABLE readiness_check (
    tenant_id   BINARY(16)   NOT NULL,
    partner_id  BINARY(16)   NOT NULL,
    code        VARCHAR(40)  NOT NULL,
    status      VARCHAR(16)  NOT NULL,
    source      VARCHAR(16)  NOT NULL,
    detail      VARCHAR(1000) NULL,
    evidence    VARCHAR(2000) NULL,
    attested_by VARCHAR(64)  NULL,
    attested_at DATETIME(6)  NULL,
    updated_at  DATETIME(6)  NOT NULL,
    CONSTRAINT pk_readiness_check PRIMARY KEY (partner_id, code),
    CONSTRAINT fk_readiness_check_partner FOREIGN KEY (tenant_id, partner_id) REFERENCES partner (tenant_id, id),
    CONSTRAINT ck_readiness_check_code CHECK (code IN (
        'PARTNER_APPROVED', 'PROGRAM_APPROVED_WITH_RULE_SET', 'DLG_AND_LIMITS_ACTIVE',
        'COLENDING_ARRANGEMENT_ACTIVE', 'PRODUCTION_CREDENTIALS_ISSUED', 'CONTRACT_TESTS_PASSED',
        'DISCLOSURE_PUBLISHED', 'DUE_DILIGENCE_VALID')),
    CONSTRAINT ck_readiness_check_status CHECK (status IN ('PASSED', 'PENDING', 'FAILED', 'NOT_APPLICABLE')),
    CONSTRAINT ck_readiness_check_source CHECK (source IN ('SYSTEM', 'EVENT', 'ATTESTATION')),
    CONSTRAINT ck_readiness_check_attested CHECK (source <> 'ATTESTATION' OR status <> 'PASSED'
        OR (attested_by IS NOT NULL AND attested_at IS NOT NULL AND evidence IS NOT NULL))
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
