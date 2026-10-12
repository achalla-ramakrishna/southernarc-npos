-- Partner API credentials (UC-01.05). Metadata only: secrets live in Keycloak and Vault and are never
-- stored here (ADR-0009).

CREATE TABLE api_client (
    id                       BINARY(16)    NOT NULL,
    tenant_id                BINARY(16)    NOT NULL,
    partner_id               BINARY(16)    NOT NULL,
    environment              VARCHAR(16)   NOT NULL,
    client_id                VARCHAR(128)  NULL,      -- Keycloak client ID, set once issued
    status                   VARCHAR(32)   NOT NULL,
    scopes                   JSON          NOT NULL,
    rate_limit_per_second    INT           NOT NULL,
    rate_limit_per_day       INT           NOT NULL,
    cert_fingerprint_sha256  CHAR(64)      NULL,
    cert_expires_at          DATETIME(6)   NULL,
    ip_allow_list            JSON          NOT NULL,
    webhook_url              VARCHAR(2048) NULL,
    webhook_signing_key_id   VARCHAR(128)  NULL,      -- Vault key reference, not the key
    webhook_verification     VARCHAR(16)   NULL,
    secret_expires_at        DATETIME(6)   NULL,
    rotation_overlap_ends_at DATETIME(6)   NULL,
    status_before_restriction VARCHAR(32)  NULL,      -- restored on reinstatement (UC-01.07 A2)
    revoked_at               DATETIME(6)   NULL,
    revocation_reason        VARCHAR(1000) NULL,
    snapshot_revision        BIGINT        NOT NULL DEFAULT 0,
    row_version              INT           NOT NULL DEFAULT 0,
    created_by               VARCHAR(64)   NOT NULL,
    created_at               DATETIME(6)   NOT NULL,
    updated_by               VARCHAR(64)   NOT NULL,
    updated_at               DATETIME(6)   NOT NULL,
    CONSTRAINT pk_api_client PRIMARY KEY (id),
    CONSTRAINT uk_api_client_client_id UNIQUE (environment, client_id),
    CONSTRAINT fk_api_client_partner FOREIGN KEY (tenant_id, partner_id) REFERENCES partner (tenant_id, id),
    CONSTRAINT ck_api_client_environment CHECK (environment IN ('SANDBOX', 'PRODUCTION')),
    CONSTRAINT ck_api_client_status CHECK (status IN (
        'REQUESTED', 'AWAITING_PARTNER_DETAILS', 'ACTIVE', 'ROTATING', 'RESTRICTED', 'REVOKED', 'EXPIRED')),
    CONSTRAINT ck_api_client_rates CHECK (rate_limit_per_second > 0 AND rate_limit_per_day > 0),
    CONSTRAINT ck_api_client_webhook_https CHECK (webhook_url IS NULL OR webhook_url LIKE 'https://%'),
    CONSTRAINT ck_api_client_webhook_verification CHECK (
        webhook_verification IS NULL OR webhook_verification IN ('VERIFIED', 'UNVERIFIED')),
    CONSTRAINT ck_api_client_revoked CHECK (status <> 'REVOKED' OR (revoked_at IS NOT NULL AND revocation_reason IS NOT NULL)),
    CONSTRAINT ck_api_client_scopes CHECK (JSON_TYPE(scopes) = 'ARRAY'),
    CONSTRAINT ck_api_client_ips CHECK (JSON_TYPE(ip_allow_list) = 'ARRAY'),
    INDEX ix_api_client_partner (tenant_id, partner_id, environment),
    -- Expiry and rotation reminders (BR-01.05-02, NFR-UP01-S08).
    INDEX ix_api_client_secret_expiry (status, secret_expires_at),
    INDEX ix_api_client_cert_expiry (status, cert_expires_at)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- One-time links sent to partner technical contacts. Only a SHA-256 hash of the token is stored.
CREATE TABLE credential_request_token (
    token_hash    CHAR(64)    NOT NULL,
    tenant_id     BINARY(16)  NOT NULL,
    api_client_id BINARY(16)  NOT NULL,
    purpose       VARCHAR(24) NOT NULL,
    expires_at    DATETIME(6) NOT NULL,
    used_at       DATETIME(6) NULL,
    created_at    DATETIME(6) NOT NULL,
    CONSTRAINT pk_credential_request_token PRIMARY KEY (token_hash),
    CONSTRAINT fk_credential_request_token_client FOREIGN KEY (api_client_id) REFERENCES api_client (id),
    CONSTRAINT ck_credential_request_token_purpose CHECK (purpose IN ('PARTNER_DETAILS')),
    INDEX ix_credential_request_token_expiry (expires_at)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
