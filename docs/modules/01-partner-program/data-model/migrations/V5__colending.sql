-- Co-lending arrangements (UC-01.03). Owned by the originating lender's tenant; the co-lender's tenant
-- gets access only through arrangement_party (ADR-0003).

CREATE TABLE colending_arrangement (
    id                     BINARY(16)  NOT NULL,
    tenant_id              BINARY(16)  NOT NULL,   -- owner tenant
    arrangement_code       VARCHAR(16) NULL,       -- CLA-nnnnnn
    originating_lender_kind VARCHAR(8) NOT NULL,
    originating_lender_id  BINARY(16)  NOT NULL,
    co_lender_kind         VARCHAR(8)  NOT NULL,
    co_lender_id           BINARY(16)  NOT NULL,
    originator_partner_id  BINARY(16)  NULL,
    status                 VARCHAR(24) NOT NULL,
    active_version         INT         NULL,
    latest_version         INT         NOT NULL,
    snapshot_revision      BIGINT      NOT NULL DEFAULT 0,
    row_version            INT         NOT NULL DEFAULT 0,
    created_by             VARCHAR(64) NOT NULL,
    created_at             DATETIME(6) NOT NULL,
    updated_by             VARCHAR(64) NOT NULL,
    updated_at             DATETIME(6) NOT NULL,
    CONSTRAINT pk_colending_arrangement PRIMARY KEY (id),
    CONSTRAINT uk_colending_arrangement_code UNIQUE (arrangement_code),
    CONSTRAINT uk_colending_arrangement_tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_colending_arrangement_tenant FOREIGN KEY (tenant_id) REFERENCES tenant (id),
    CONSTRAINT fk_colending_arrangement_originator FOREIGN KEY (tenant_id, originator_partner_id) REFERENCES partner (tenant_id, id),
    CONSTRAINT ck_colending_lender_kinds CHECK (
        originating_lender_kind IN ('TENANT', 'PARTNER') AND co_lender_kind IN ('TENANT', 'PARTNER')),
    CONSTRAINT ck_colending_distinct_lenders CHECK (
        NOT (originating_lender_kind = co_lender_kind AND originating_lender_id = co_lender_id)),
    CONSTRAINT ck_colending_status CHECK (status IN (
        'DRAFT', 'PENDING_APPROVAL', 'RETURNED', 'REJECTED', 'PENDING_VERIFICATION', 'ACTIVE',
        'SUSPENDED', 'SUPERSEDED', 'EXPIRED', 'CANCELLED')),
    INDEX ix_colending_originator (tenant_id, originator_partner_id),
    INDEX ix_colending_status (tenant_id, status)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Tenants allowed to see an arrangement besides its owner (the co-lender's tenant, when it is a tenant).
CREATE TABLE arrangement_party (
    arrangement_id  BINARY(16) NOT NULL,
    party_tenant_id BINARY(16) NOT NULL,
    role            VARCHAR(24) NOT NULL,
    CONSTRAINT pk_arrangement_party PRIMARY KEY (arrangement_id, party_tenant_id),
    CONSTRAINT fk_arrangement_party_arrangement FOREIGN KEY (arrangement_id) REFERENCES colending_arrangement (id),
    CONSTRAINT fk_arrangement_party_tenant FOREIGN KEY (party_tenant_id) REFERENCES tenant (id),
    CONSTRAINT ck_arrangement_party_role CHECK (role IN ('CO_LENDER')),
    INDEX ix_arrangement_party_tenant (party_tenant_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE arrangement_version (
    id                           BINARY(16)  NOT NULL,
    tenant_id                    BINARY(16)  NOT NULL,
    arrangement_id               BINARY(16)  NOT NULL,
    version                      INT         NOT NULL,
    status                       VARCHAR(24) NOT NULL,
    effective_from               DATETIME(6) NULL,
    effective_to                 DATETIME(6) NULL,
    content                      JSON        NOT NULL,
    content_schema_version       SMALLINT    NOT NULL DEFAULT 1,
    change_request_id            BINARY(16)  NOT NULL,
    copied_from_version          INT         NULL,
    approved_at                  DATETIME(6) NULL,
    escrow_confirmed_at          DATETIME(6) NULL,
    core_system_acknowledged_at  DATETIME(6) NULL,
    verification_attempts        INT         NOT NULL DEFAULT 0,
    last_verification_attempt_at DATETIME(6) NULL,
    row_version                  INT         NOT NULL DEFAULT 0,
    created_by                   VARCHAR(64) NOT NULL,
    created_at                   DATETIME(6) NOT NULL,
    updated_by                   VARCHAR(64) NOT NULL,
    updated_at                   DATETIME(6) NOT NULL,
    active_parent_id             BINARY(16)  GENERATED ALWAYS AS (CASE WHEN status = 'ACTIVE' THEN arrangement_id END) STORED,
    CONSTRAINT pk_arrangement_version PRIMARY KEY (id),
    CONSTRAINT uk_arrangement_version UNIQUE (arrangement_id, version),
    CONSTRAINT uk_arrangement_version_active UNIQUE (active_parent_id),
    CONSTRAINT fk_arrangement_version_arrangement FOREIGN KEY (tenant_id, arrangement_id) REFERENCES colending_arrangement (tenant_id, id),
    CONSTRAINT fk_arrangement_version_cr FOREIGN KEY (tenant_id, change_request_id) REFERENCES change_request (tenant_id, id),
    CONSTRAINT ck_arrangement_version_status CHECK (status IN (
        'DRAFT', 'PENDING_APPROVAL', 'RETURNED', 'REJECTED', 'PENDING_VERIFICATION', 'SCHEDULED', 'ACTIVE',
        'SUSPENDED', 'SUPERSEDED', 'EXPIRED', 'CANCELLED')),
    -- C5: an arrangement version is ACTIVE only after both verifications.
    CONSTRAINT ck_arrangement_version_verified CHECK (
        status <> 'ACTIVE' OR (escrow_confirmed_at IS NOT NULL AND core_system_acknowledged_at IS NOT NULL)),
    CONSTRAINT ck_arrangement_version_period CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT ck_arrangement_version_content CHECK (JSON_TYPE(content) = 'OBJECT'),
    INDEX ix_arrangement_version_due (status, effective_from),
    INDEX ix_arrangement_version_cr (change_request_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
