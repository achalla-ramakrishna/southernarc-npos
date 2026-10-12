-- Cross-cutting tables: tamper-evident audit log, transactional outbox, idempotency keys,
-- scheduler lock, configuration packages.

-- Append-only audit log (NFR-UP01-AU01, AU02). Hash-chained per aggregate:
--   hash = SHA-256(previous_hash || canonical JSON of this record), computed by the service.
-- Triggers below reject UPDATE and DELETE and check chain continuity on INSERT. In production the
-- application database user is also granted only SELECT and INSERT on this table.
CREATE TABLE audit_record (
    id                BINARY(16)   NOT NULL,
    tenant_id         BINARY(16)   NOT NULL,
    aggregate_type    VARCHAR(32)  NOT NULL,
    aggregate_id      BINARY(16)   NOT NULL,
    aggregate_seq     INT          NOT NULL,
    occurred_at       DATETIME(6)  NOT NULL,
    actor             VARCHAR(64)  NOT NULL,   -- user ID, or SYSTEM
    actor_role        VARCHAR(40)  NULL,
    source_ip         VARCHAR(45)  NULL,
    action            VARCHAR(32)  NOT NULL,
    version           INT          NULL,
    change_request_id BINARY(16)   NULL,
    before_state      JSON         NULL,
    after_state       JSON         NULL,
    comment           VARCHAR(2000) NULL,
    previous_hash     CHAR(64)     NOT NULL,   -- 64 zeros for the first record of an aggregate
    hash              CHAR(64)     NOT NULL,
    CONSTRAINT pk_audit_record PRIMARY KEY (id),
    CONSTRAINT uk_audit_record_chain UNIQUE (aggregate_type, aggregate_id, aggregate_seq),
    CONSTRAINT ck_audit_record_seq CHECK (aggregate_seq >= 1),
    INDEX ix_audit_record_tenant_time (tenant_id, occurred_at),
    INDEX ix_audit_record_actor (tenant_id, actor, occurred_at),
    INDEX ix_audit_record_cr (change_request_id)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

DELIMITER $$
CREATE TRIGGER tr_audit_record_no_update
BEFORE UPDATE ON audit_record
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'AUDIT_RECORD_IMMUTABLE';
END$$

CREATE TRIGGER tr_audit_record_no_delete
BEFORE DELETE ON audit_record
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'AUDIT_RECORD_IMMUTABLE';
END$$

CREATE TRIGGER tr_audit_record_chain
BEFORE INSERT ON audit_record
FOR EACH ROW
BEGIN
    DECLARE v_prev_hash CHAR(64);
    IF NEW.aggregate_seq = 1 THEN
        IF NEW.previous_hash <> REPEAT('0', 64) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'AUDIT_CHAIN_BROKEN';
        END IF;
    ELSE
        SELECT hash INTO v_prev_hash FROM audit_record
         WHERE aggregate_type = NEW.aggregate_type AND aggregate_id = NEW.aggregate_id
           AND aggregate_seq = NEW.aggregate_seq - 1;
        IF v_prev_hash IS NULL OR v_prev_hash <> NEW.previous_hash THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'AUDIT_CHAIN_BROKEN';
        END IF;
    END IF;
END$$
DELIMITER ;

-- Transactional outbox (ADR-0002). Written in the same transaction as the business change and
-- streamed to Kafka by Debezium's outbox event router. Rows are deleted by a purge job once the
-- connector has read them (Debezium reads the binlog, so deletion does not lose events).
CREATE TABLE outbox_event (
    id             BINARY(16)   NOT NULL,   -- also the CloudEvents ce_id
    tenant_id      BINARY(16)   NOT NULL,
    aggregate_type VARCHAR(40)  NOT NULL,
    aggregate_id   VARCHAR(36)  NOT NULL,   -- Kafka key
    topic          VARCHAR(200) NOT NULL,
    event_type     VARCHAR(200) NOT NULL,   -- CloudEvents ce_type
    revision       BIGINT       NOT NULL,   -- snapshot revision of the aggregate
    headers        JSON         NOT NULL,   -- remaining ce_* headers
    payload        JSON         NOT NULL,
    created_at     DATETIME(6)  NOT NULL,
    CONSTRAINT pk_outbox_event PRIMARY KEY (id),
    CONSTRAINT uk_outbox_event_revision UNIQUE (topic, aggregate_id, revision),
    INDEX ix_outbox_event_created (created_at)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Idempotency-Key handling for POST endpoints (contracts README). Kept 24 hours.
CREATE TABLE idempotency_record (
    tenant_id       BINARY(16)   NOT NULL,
    idempotency_key CHAR(36)     NOT NULL,
    operation       VARCHAR(100) NOT NULL,
    request_hash    CHAR(64)     NOT NULL,
    response_status SMALLINT     NULL,       -- NULL while the first request is still running
    response_body   JSON         NULL,
    resource_id     BINARY(16)   NULL,
    created_at      DATETIME(6)  NOT NULL,
    expires_at      DATETIME(6)  NOT NULL,
    CONSTRAINT pk_idempotency_record PRIMARY KEY (tenant_id, idempotency_key),
    INDEX ix_idempotency_record_expiry (expires_at)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- ShedLock: ensures a scheduled job (version activation, expiry reminders, purges) runs on only one
-- replica at a time.
CREATE TABLE shedlock (
    name       VARCHAR(64)  NOT NULL,
    lock_until TIMESTAMP(3) NOT NULL,
    locked_at  TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    locked_by  VARCHAR(255) NOT NULL,
    CONSTRAINT pk_shedlock PRIMARY KEY (name)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Configuration packages (ADR-0010). The package file itself is stored in the document service.
CREATE TABLE config_package (
    id                  BINARY(16)   NOT NULL,
    tenant_id           BINARY(16)   NOT NULL,
    schema_version      VARCHAR(8)   NOT NULL,
    source_installation VARCHAR(64)  NOT NULL,
    sha256              CHAR(64)     NOT NULL,
    manifest            JSON         NOT NULL,
    document_id         VARCHAR(64)  NOT NULL,
    created_by          VARCHAR(64)  NOT NULL,
    created_at          DATETIME(6)  NOT NULL,
    CONSTRAINT pk_config_package PRIMARY KEY (id),
    CONSTRAINT fk_config_package_tenant FOREIGN KEY (tenant_id) REFERENCES tenant (id),
    INDEX ix_config_package_tenant (tenant_id, created_at)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

CREATE TABLE config_import (
    id              BINARY(16)  NOT NULL,
    tenant_id       BINARY(16)  NOT NULL,
    package_sha256  CHAR(64)    NOT NULL,
    signature_valid BOOLEAN     NOT NULL,
    status          VARCHAR(16) NOT NULL,
    diff            JSON        NOT NULL,
    validation      JSON        NOT NULL,
    document_id     VARCHAR(64) NOT NULL,
    applied_at      DATETIME(6) NULL,
    created_by      VARCHAR(64) NOT NULL,
    created_at      DATETIME(6) NOT NULL,
    -- A package can be applied only once per tenant (ADR-0010 §4).
    applied_key     CHAR(64)    GENERATED ALWAYS AS (CASE WHEN status = 'APPLIED' THEN package_sha256 END) STORED,
    CONSTRAINT pk_config_import PRIMARY KEY (id),
    CONSTRAINT uk_config_import_applied UNIQUE (tenant_id, applied_key),
    CONSTRAINT fk_config_import_tenant FOREIGN KEY (tenant_id) REFERENCES tenant (id),
    CONSTRAINT ck_config_import_status CHECK (status IN ('PREPARED', 'APPLIED', 'FAILED')),
    CONSTRAINT ck_config_import_signed CHECK (status <> 'APPLIED' OR signature_valid)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;
