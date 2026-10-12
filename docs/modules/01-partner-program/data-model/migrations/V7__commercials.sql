-- Partner commercials (UC-01.06).

CREATE TABLE commercial_schedule (
    id                BINARY(16)  NOT NULL,
    tenant_id         BINARY(16)  NOT NULL,
    partner_id        BINARY(16)  NOT NULL,
    schedule_code     VARCHAR(16) NULL,       -- COM-nnnnnn
    erp_vendor_code   VARCHAR(40) NULL,
    erp_customer_code VARCHAR(40) NULL,
    active_version    INT         NULL,
    latest_version    INT         NOT NULL,
    snapshot_revision BIGINT      NOT NULL DEFAULT 0,
    row_version       INT         NOT NULL DEFAULT 0,
    created_by        VARCHAR(64) NOT NULL,
    created_at        DATETIME(6) NOT NULL,
    updated_by        VARCHAR(64) NOT NULL,
    updated_at        DATETIME(6) NOT NULL,
    CONSTRAINT pk_commercial_schedule PRIMARY KEY (id),
    CONSTRAINT uk_commercial_schedule_code UNIQUE (schedule_code),
    CONSTRAINT uk_commercial_schedule_tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_commercial_schedule_partner FOREIGN KEY (tenant_id, partner_id) REFERENCES partner (tenant_id, id),
    INDEX ix_commercial_schedule_partner (tenant_id, partner_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE commercial_version (
    id                     BINARY(16)  NOT NULL,
    tenant_id              BINARY(16)  NOT NULL,
    schedule_id            BINARY(16)  NOT NULL,
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
    active_parent_id       BINARY(16)  GENERATED ALWAYS AS (CASE WHEN status = 'ACTIVE' THEN schedule_id END) STORED,
    CONSTRAINT pk_commercial_version PRIMARY KEY (id),
    CONSTRAINT uk_commercial_version UNIQUE (schedule_id, version),
    CONSTRAINT uk_commercial_version_active UNIQUE (active_parent_id),
    CONSTRAINT fk_commercial_version_schedule FOREIGN KEY (tenant_id, schedule_id) REFERENCES commercial_schedule (tenant_id, id),
    CONSTRAINT fk_commercial_version_cr FOREIGN KEY (tenant_id, change_request_id) REFERENCES change_request (tenant_id, id),
    CONSTRAINT ck_commercial_version_status CHECK (status IN (
        'DRAFT', 'PENDING_APPROVAL', 'RETURNED', 'REJECTED', 'SCHEDULED', 'ACTIVE', 'SUPERSEDED', 'RETIRED', 'CANCELLED')),
    CONSTRAINT ck_commercial_version_period CHECK (effective_to IS NULL OR effective_to > effective_from),
    CONSTRAINT ck_commercial_version_content CHECK (JSON_TYPE(content) = 'OBJECT'),
    INDEX ix_commercial_version_due (status, effective_from),
    INDEX ix_commercial_version_cr (change_request_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
