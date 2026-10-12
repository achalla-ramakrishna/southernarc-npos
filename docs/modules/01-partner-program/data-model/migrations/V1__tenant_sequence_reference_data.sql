-- Module 1 partner-config-service: tenants, business ID sequences, reference data.
-- Conventions (see ../../data-model.md):
--   * Technical IDs are UUIDv7 stored as BINARY(16) (time-ordered, so InnoDB inserts stay sequential).
--   * Every business table carries tenant_id; parents expose UNIQUE (tenant_id, id) so children can use
--     composite foreign keys that make cross-tenant references impossible (ADR-0003).
--   * Timestamps are DATETIME(6) in UTC. Money is BIGINT paise; rates are INT basis points.
--   * Closed value sets use VARCHAR + CHECK (values match the API enums; no ENUM ordinal pitfalls).

CREATE TABLE tenant (
    id                BINARY(16)   NOT NULL,
    code              VARCHAR(20)  NOT NULL,
    name              VARCHAR(200) NOT NULL,
    deployment_model  VARCHAR(16)  NOT NULL,
    home_lender       JSON         NOT NULL,
    status            VARCHAR(16)  NOT NULL,
    snapshot_revision BIGINT       NOT NULL DEFAULT 0,
    created_by        VARCHAR(64)  NOT NULL,
    created_at        DATETIME(6)  NOT NULL,
    updated_by        VARCHAR(64)  NOT NULL,
    updated_at        DATETIME(6)  NOT NULL,
    CONSTRAINT pk_tenant PRIMARY KEY (id),
    CONSTRAINT uk_tenant_code UNIQUE (code),
    CONSTRAINT ck_tenant_deployment CHECK (deployment_model IN ('HOSTED', 'ON_PREMISE')),
    CONSTRAINT ck_tenant_status CHECK (status IN ('PROVISIONING', 'ACTIVE', 'SUSPENDED')),
    CONSTRAINT ck_tenant_home_lender CHECK (JSON_TYPE(home_lender) = 'OBJECT')
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Human-readable business IDs (PTR-000123, PRG-000456, CR-000789 ...), unique per installation and
-- never reused. Incremented with SELECT ... FOR UPDATE inside the approving transaction.
CREATE TABLE business_id_sequence (
    prefix     VARCHAR(8) NOT NULL,
    next_value BIGINT     NOT NULL,
    CONSTRAINT pk_business_id_sequence PRIMARY KEY (prefix),
    CONSTRAINT ck_business_id_sequence_positive CHECK (next_value > 0)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

INSERT INTO business_id_sequence (prefix, next_value) VALUES
    ('PTR', 1), ('PRG', 1), ('CLA', 1), ('LST', 1), ('DLG', 1), ('COM', 1), ('CR', 1);

-- Versioned reference data per tenant: partner types, document checklists, product master,
-- charge types, reason codes, approval matrix, regulatory parameters, interest rate policy.
CREATE TABLE reference_data_version (
    id                BINARY(16)  NOT NULL,
    tenant_id         BINARY(16)  NOT NULL,
    category          VARCHAR(40) NOT NULL,
    version           INT         NOT NULL,
    status            VARCHAR(24) NOT NULL,
    effective_from    DATETIME(6) NULL,
    effective_to      DATETIME(6) NULL,
    entries           JSON        NOT NULL,
    change_request_id BINARY(16)  NULL,
    approved_at       DATETIME(6) NULL,
    created_by        VARCHAR(64) NOT NULL,
    created_at        DATETIME(6) NOT NULL,
    updated_by        VARCHAR(64) NOT NULL,
    updated_at        DATETIME(6) NOT NULL,
    -- At most one ACTIVE version per (tenant, category).
    active_key        VARCHAR(80) GENERATED ALWAYS AS
                          (CASE WHEN status = 'ACTIVE' THEN CONCAT(HEX(tenant_id), ':', category) END) STORED,
    CONSTRAINT pk_reference_data_version PRIMARY KEY (id),
    CONSTRAINT uk_reference_data_version UNIQUE (tenant_id, category, version),
    CONSTRAINT uk_reference_data_active UNIQUE (active_key),
    CONSTRAINT fk_reference_data_tenant FOREIGN KEY (tenant_id) REFERENCES tenant (id),
    CONSTRAINT ck_reference_data_category CHECK (category IN (
        'PARTNER_TYPES', 'DOCUMENT_CHECKLISTS', 'PRODUCTS', 'CHARGE_TYPES', 'REASON_CODES',
        'APPROVAL_MATRIX', 'REGULATORY_PARAMETERS', 'INTEREST_RATE_POLICY')),
    CONSTRAINT ck_reference_data_status CHECK (status IN (
        'DRAFT', 'PENDING_APPROVAL', 'RETURNED', 'REJECTED', 'SCHEDULED', 'ACTIVE', 'SUPERSEDED', 'CANCELLED')),
    CONSTRAINT ck_reference_data_period CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT ck_reference_data_entries CHECK (JSON_TYPE(entries) = 'ARRAY'),
    INDEX ix_reference_data_due (status, effective_from)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
