-- Maker-checker change requests (ADR-0005). Every draft version and every status change
-- (suspend, retire, rollback ...) is owned by exactly one change request.

CREATE TABLE change_request (
    id               BINARY(16)   NOT NULL,
    tenant_id        BINARY(16)   NOT NULL,
    cr_code          VARCHAR(16)  NOT NULL,
    type             VARCHAR(40)  NOT NULL,
    aggregate_type   VARCHAR(32)  NOT NULL,
    aggregate_id     BINARY(16)   NOT NULL,
    target_version   INT          NULL,
    status           VARCHAR(16)  NOT NULL,
    emergency        BOOLEAN      NOT NULL DEFAULT FALSE,
    summary          VARCHAR(500) NOT NULL,
    -- Parameters of status-change requests (retire date, suspension order id, cancelled version ...).
    payload          JSON         NULL,
    maker_user_id    VARCHAR(64)  NOT NULL,
    submitted_at     DATETIME(6)  NULL,
    due_by           DATETIME(6)  NULL,
    applied_at       DATETIME(6)  NULL,
    apply_attempts   INT          NOT NULL DEFAULT 0,
    last_apply_error VARCHAR(1000) NULL,
    row_version      INT          NOT NULL DEFAULT 0,
    created_by       VARCHAR(64)  NOT NULL,
    created_at       DATETIME(6)  NOT NULL,
    updated_by       VARCHAR(64)  NOT NULL,
    updated_at       DATETIME(6)  NOT NULL,
    CONSTRAINT pk_change_request PRIMARY KEY (id),
    CONSTRAINT uk_change_request_code UNIQUE (cr_code),
    CONSTRAINT uk_change_request_tenant_id UNIQUE (tenant_id, id),
    CONSTRAINT fk_change_request_tenant FOREIGN KEY (tenant_id) REFERENCES tenant (id),
    CONSTRAINT ck_change_request_type CHECK (type IN (
        'ONBOARD_PARTNER', 'UPDATE_PARTNER_PROFILE', 'PROGRAM_VERSION', 'RETIRE_PROGRAM',
        'ARRANGEMENT_VERSION', 'SUSPEND_ARRANGEMENT', 'REINSTATE_ARRANGEMENT', 'LIMIT_SET_VERSION',
        'DLG_COVER_VERSION', 'COMMERCIAL_VERSION', 'SUSPEND_PARTNER', 'REINSTATE_PARTNER',
        'OFFBOARD_PARTNER', 'ROLLBACK', 'CANCEL_SCHEDULED_VERSION', 'REFERENCE_DATA_VERSION',
        'REGULATORY_PARAMETER_VERSION')),
    CONSTRAINT ck_change_request_aggregate CHECK (aggregate_type IN (
        'PARTNER', 'PROGRAM', 'ARRANGEMENT', 'LIMIT_SET', 'DLG_COVER', 'COMMERCIAL_SCHEDULE',
        'REFERENCE_DATA', 'REGULATORY_PARAMETER')),
    CONSTRAINT ck_change_request_status CHECK (status IN (
        'DRAFT', 'SUBMITTED', 'IN_APPROVAL', 'RETURNED', 'APPROVED', 'REJECTED', 'WITHDRAWN',
        'APPLIED', 'APPLY_FAILED')),
    INDEX ix_change_request_status_due (tenant_id, status, due_by),
    INDEX ix_change_request_aggregate (tenant_id, aggregate_type, aggregate_id),
    INDEX ix_change_request_maker (tenant_id, maker_user_id, status)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Ordered approval steps, generated at submission from the approval matrix.
-- step_tenant_id differs from the request's tenant for co-lender approvals (ADR-0003).
CREATE TABLE approval_step (
    id                BINARY(16)   NOT NULL,
    change_request_id BINARY(16)   NOT NULL,
    sequence          SMALLINT     NOT NULL,
    role              VARCHAR(40)  NOT NULL,
    step_tenant_id    BINARY(16)   NOT NULL,
    status            VARCHAR(16)  NOT NULL,
    decided_by        VARCHAR(64)  NULL,
    decided_at        DATETIME(6)  NULL,
    comment           VARCHAR(2000) NULL,
    CONSTRAINT pk_approval_step PRIMARY KEY (id),
    CONSTRAINT uk_approval_step_sequence UNIQUE (change_request_id, sequence),
    CONSTRAINT fk_approval_step_request FOREIGN KEY (change_request_id) REFERENCES change_request (id),
    CONSTRAINT fk_approval_step_tenant FOREIGN KEY (step_tenant_id) REFERENCES tenant (id),
    CONSTRAINT ck_approval_step_status CHECK (status IN ('WAITING', 'PENDING', 'APPROVED', 'RETURNED', 'REJECTED')),
    CONSTRAINT ck_approval_step_decision CHECK (
        (status IN ('WAITING', 'PENDING') AND decided_by IS NULL AND decided_at IS NULL)
        OR (status IN ('APPROVED', 'RETURNED', 'REJECTED') AND decided_by IS NOT NULL AND decided_at IS NOT NULL)),
    CONSTRAINT ck_approval_step_comment CHECK (status NOT IN ('RETURNED', 'REJECTED') OR comment IS NOT NULL),
    -- "Awaiting my decision" work list.
    INDEX ix_approval_step_worklist (step_tenant_id, role, status)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_0900_ai_ci;

-- Defence in depth for maker-checker (BR-01.01-03, NFR-UP01-S04). The service checks this first;
-- the trigger guarantees it even if a code path forgets.
DELIMITER $$
CREATE TRIGGER tr_approval_step_maker_checker
BEFORE UPDATE ON approval_step
FOR EACH ROW
BEGIN
    DECLARE v_maker VARCHAR(64);
    DECLARE v_other_decisions INT;
    IF NEW.decided_by IS NOT NULL AND (OLD.decided_by IS NULL OR OLD.decided_by <> NEW.decided_by) THEN
        SELECT maker_user_id INTO v_maker FROM change_request WHERE id = NEW.change_request_id;
        IF v_maker = NEW.decided_by THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'MAKER_CANNOT_APPROVE';
        END IF;
        SELECT COUNT(*) INTO v_other_decisions FROM approval_step
         WHERE change_request_id = NEW.change_request_id AND id <> NEW.id AND decided_by = NEW.decided_by;
        IF v_other_decisions > 0 THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'APPROVER_ALREADY_DECIDED';
        END IF;
    END IF;
END$$
DELIMITER ;
