-- Exposure limit definitions and DLG (UC-01.04). Utilisation is owned by Module 7 (ADR-0008).

CREATE TABLE limit_set (
    id                BINARY(16)  NOT NULL,
    tenant_id         BINARY(16)  NOT NULL,
    partner_id        BINARY(16)  NOT NULL,
    limit_set_code    VARCHAR(16) NULL,       -- LST-nnnnnn
    active_version    INT         NULL,
    latest_version    INT         NOT NULL,
    snapshot_revision BIGINT      NOT NULL DEFAULT 0,
    row_version       INT         NOT NULL DEFAULT 0,
    created_by        VARCHAR(64) NOT NULL,
    created_at        DATETIME(6) NOT NULL,
    updated_by        VARCHAR(64) NOT NULL,
    updated_at        DATETIME(6) NOT NULL,
    CONSTRAINT pk_limit_set PRIMARY KEY (id),
    CONSTRAINT uk_limit_set_code UNIQUE (limit_set_code),
    CONSTRAINT uk_limit_set_tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_limit_set_partner FOREIGN KEY (tenant_id, partner_id) REFERENCES partner (tenant_id, id),
    INDEX ix_limit_set_partner (tenant_id, partner_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE limit_set_version (
    id                     BINARY(16)  NOT NULL,
    tenant_id              BINARY(16)  NOT NULL,
    limit_set_id           BINARY(16)  NOT NULL,
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
    active_parent_id       BINARY(16)  GENERATED ALWAYS AS (CASE WHEN status = 'ACTIVE' THEN limit_set_id END) STORED,
    CONSTRAINT pk_limit_set_version PRIMARY KEY (id),
    CONSTRAINT uk_limit_set_version UNIQUE (limit_set_id, version),
    CONSTRAINT uk_limit_set_version_active UNIQUE (active_parent_id),
    CONSTRAINT fk_limit_set_version_set FOREIGN KEY (tenant_id, limit_set_id) REFERENCES limit_set (tenant_id, id),
    CONSTRAINT fk_limit_set_version_cr FOREIGN KEY (tenant_id, change_request_id) REFERENCES change_request (tenant_id, id),
    CONSTRAINT ck_limit_set_version_status CHECK (status IN (
        'DRAFT', 'PENDING_APPROVAL', 'RETURNED', 'REJECTED', 'SCHEDULED', 'ACTIVE', 'SUPERSEDED', 'RETIRED', 'CANCELLED')),
    CONSTRAINT ck_limit_set_version_period CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT ck_limit_set_version_content CHECK (JSON_TYPE(content) = 'OBJECT'),
    INDEX ix_limit_set_version_due (status, effective_from),
    INDEX ix_limit_set_version_cr (change_request_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE dlg_cover (
    id                BINARY(16)  NOT NULL,
    tenant_id         BINARY(16)  NOT NULL,
    partner_id        BINARY(16)  NOT NULL,
    dlg_code          VARCHAR(16) NULL,       -- DLG-nnnnnn
    active_version    INT         NULL,
    latest_version    INT         NOT NULL,
    snapshot_revision BIGINT      NOT NULL DEFAULT 0,
    row_version       INT         NOT NULL DEFAULT 0,
    created_by        VARCHAR(64) NOT NULL,
    created_at        DATETIME(6) NOT NULL,
    updated_by        VARCHAR(64) NOT NULL,
    updated_at        DATETIME(6) NOT NULL,
    CONSTRAINT pk_dlg_cover PRIMARY KEY (id),
    CONSTRAINT uk_dlg_cover_code UNIQUE (dlg_code),
    CONSTRAINT uk_dlg_cover_tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_dlg_cover_partner FOREIGN KEY (tenant_id, partner_id) REFERENCES partner (tenant_id, id),
    INDEX ix_dlg_cover_partner (tenant_id, partner_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE dlg_cover_version (
    id                     BINARY(16)  NOT NULL,
    tenant_id              BINARY(16)  NOT NULL,
    dlg_cover_id           BINARY(16)  NOT NULL,
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
    dlg_form               VARCHAR(32) GENERATED ALWAYS AS (content->>'$.form') STORED,
    active_parent_id       BINARY(16)  GENERATED ALWAYS AS (CASE WHEN status = 'ACTIVE' THEN dlg_cover_id END) STORED,
    CONSTRAINT pk_dlg_cover_version PRIMARY KEY (id),
    CONSTRAINT uk_dlg_cover_version UNIQUE (dlg_cover_id, version),
    CONSTRAINT uk_dlg_cover_version_active UNIQUE (active_parent_id),
    CONSTRAINT fk_dlg_cover_version_cover FOREIGN KEY (tenant_id, dlg_cover_id) REFERENCES dlg_cover (tenant_id, id),
    CONSTRAINT fk_dlg_cover_version_cr FOREIGN KEY (tenant_id, change_request_id) REFERENCES change_request (tenant_id, id),
    CONSTRAINT ck_dlg_cover_version_status CHECK (status IN (
        'DRAFT', 'PENDING_APPROVAL', 'RETURNED', 'REJECTED', 'SCHEDULED', 'ACTIVE', 'SUPERSEDED', 'RETIRED', 'CANCELLED')),
    -- BR-01.04-02 allowed DLG forms (NULL while the draft is incomplete).
    CONSTRAINT ck_dlg_cover_version_form CHECK (
        dlg_form IS NULL OR dlg_form IN ('CASH_DEPOSIT', 'FIXED_DEPOSIT_WITH_LIEN', 'BANK_GUARANTEE')),
    CONSTRAINT ck_dlg_cover_version_period CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT ck_dlg_cover_version_content CHECK (JSON_TYPE(content) = 'OBJECT'),
    INDEX ix_dlg_cover_version_due (status, effective_from),
    INDEX ix_dlg_cover_version_cr (change_request_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE dlg_instrument (
    id                   BINARY(16)   NOT NULL,
    tenant_id            BINARY(16)   NOT NULL,
    dlg_cover_id         BINARY(16)   NOT NULL,
    form                 VARCHAR(32)  NOT NULL,
    reference_number     VARCHAR(64)  NOT NULL,
    issuing_bank         VARCHAR(200) NULL,
    amount_paise         BIGINT       NOT NULL,
    expiry_date          DATE         NULL,
    lien_status          VARCHAR(16)  NULL,
    evidence_document_id VARCHAR(64)  NULL,
    status               VARCHAR(24)  NOT NULL,
    verified_by          VARCHAR(64)  NULL,
    verified_at          DATETIME(6)  NULL,
    not_verified_reason  VARCHAR(1000) NULL,
    row_version          INT          NOT NULL DEFAULT 0,
    created_by           VARCHAR(64)  NOT NULL,
    created_at           DATETIME(6)  NOT NULL,
    updated_by           VARCHAR(64)  NOT NULL,
    updated_at           DATETIME(6)  NOT NULL,
    CONSTRAINT pk_dlg_instrument PRIMARY KEY (id),
    CONSTRAINT fk_dlg_instrument_cover FOREIGN KEY (tenant_id, dlg_cover_id) REFERENCES dlg_cover (tenant_id, id),
    CONSTRAINT ck_dlg_instrument_form CHECK (form IN ('CASH_DEPOSIT', 'FIXED_DEPOSIT_WITH_LIEN', 'BANK_GUARANTEE')),
    CONSTRAINT ck_dlg_instrument_amount CHECK (amount_paise > 0),
    CONSTRAINT ck_dlg_instrument_expiry CHECK (form = 'CASH_DEPOSIT' OR expiry_date IS NOT NULL),
    CONSTRAINT ck_dlg_instrument_lien CHECK (form <> 'FIXED_DEPOSIT_WITH_LIEN' OR lien_status IS NOT NULL),
    CONSTRAINT ck_dlg_instrument_status CHECK (status IN (
        'RECORDED', 'VERIFIED', 'NOT_VERIFIED', 'ACTIVE', 'EXPIRING_SOON', 'EXPIRED', 'TOP_UP_REQUIRED', 'RELEASED')),
    CONSTRAINT ck_dlg_instrument_not_verified CHECK (status <> 'NOT_VERIFIED' OR not_verified_reason IS NOT NULL),
    -- Expiry scheduler (BR-01.04-04, reminders).
    INDEX ix_dlg_instrument_expiry (status, expiry_date),
    INDEX ix_dlg_instrument_cover (tenant_id, dlg_cover_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
