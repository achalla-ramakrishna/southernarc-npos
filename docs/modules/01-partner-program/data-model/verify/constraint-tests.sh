#!/usr/bin/env bash
# Behavioural tests for the Module 1 schema: each database-level rule is exercised with data that
# must be accepted and data that must be rejected.
#
# Usage:  ./constraint-tests.sh [mysql-container-name]   (default: npos-mysql)
# Needs:  a MySQL 8.4 container with an empty `partner_config` schema and the migrations applied.
#   docker run -d --name npos-mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=partner_config mysql:8.4
#   for f in $(ls ../migrations/*.sql | sort -V); do docker exec -i npos-mysql mysql -uroot -proot partner_config < "$f"; done
set -uo pipefail

CONTAINER="${1:-npos-mysql}"
PASS=0
FAIL=0

sql() { docker exec -i "$CONTAINER" mysql -uroot -proot -N -B partner_config 2>&1 <<<"$1" | grep -v 'Using a password'; }

expect_ok() {
  local name="$1" stmt="$2" out
  out=$(sql "$stmt")
  if grep -q '^ERROR' <<<"$out"; then echo "FAIL  $name"; echo "      $out"; FAIL=$((FAIL+1)); else echo "ok    $name"; PASS=$((PASS+1)); fi
}

expect_error() {
  local name="$1" pattern="$2" stmt="$3" out
  out=$(sql "$stmt")
  if grep -q '^ERROR' <<<"$out" && grep -qE "$pattern" <<<"$out"; then echo "ok    $name"; PASS=$((PASS+1));
  else echo "FAIL  $name (expected error matching: $pattern)"; echo "      ${out:-<no error>}"; FAIL=$((FAIL+1)); fi
}

expect_index() {
  local name="$1" expected="$2" stmt="$3" out
  out=$(sql "EXPLAIN FORMAT=TRADITIONAL $stmt" | awk -F'\t' '{print $7}')
  if [[ "$out" == "$expected" ]]; then echo "ok    $name"; PASS=$((PASS+1)); else echo "FAIL  $name (expected index '$expected', got '$out')"; FAIL=$((FAIL+1)); fi
}

expect_value() {
  local name="$1" expected="$2" stmt="$3" out
  out=$(sql "$stmt")
  if [[ "$out" == "$expected" ]]; then echo "ok    $name"; PASS=$((PASS+1)); else echo "FAIL  $name (expected '$expected', got '$out')"; FAIL=$((FAIL+1)); fi
}

# Fixed IDs to keep the tests readable.
T_A="UUID_TO_BIN('0192aaaa-0000-7000-8000-000000000001')"   # tenant A (Northern Arc)
T_B="UUID_TO_BIN('0192aaaa-0000-7000-8000-000000000002')"   # tenant B (a bank)
P1="UUID_TO_BIN('0192bbbb-0000-7000-8000-000000000001')"    # partner in tenant A
P2="UUID_TO_BIN('0192bbbb-0000-7000-8000-000000000002')"    # second partner in tenant A
CR1="UUID_TO_BIN('0192cccc-0000-7000-8000-000000000001')"
CR2="UUID_TO_BIN('0192cccc-0000-7000-8000-000000000002')"
PRG="UUID_TO_BIN('0192dddd-0000-7000-8000-000000000001')"
NOW="UTC_TIMESTAMP(6)"
AUD="'tester', $NOW, 'tester', $NOW"

echo "== setup"
expect_ok "create tenants A and B" "
INSERT INTO tenant VALUES ($T_A,'NACL','Northern Arc','HOSTED','{\"legalName\":\"NACL\"}','ACTIVE',0,$AUD),
                          ($T_B,'BANKX','Bank X','HOSTED','{\"legalName\":\"Bank X\"}','ACTIVE',0,$AUD);"
expect_ok "create change requests (maker = priya)" "
INSERT INTO change_request (id,tenant_id,cr_code,type,aggregate_type,aggregate_id,status,summary,maker_user_id,created_by,created_at,updated_by,updated_at)
VALUES ($CR1,$T_A,'CR-000001','ONBOARD_PARTNER','PARTNER',$P1,'DRAFT','Onboard P1','priya',$AUD),
       ($CR2,$T_A,'CR-000002','PROGRAM_VERSION','PROGRAM',$PRG,'DRAFT','Program v1','priya',$AUD);"
expect_ok "create partners P1 and P2 in DRAFT" "
INSERT INTO partner (id,tenant_id,partner_type,display_name,status,latest_profile_version,created_by,created_at,updated_by,updated_at)
VALUES ($P1,$T_A,'FINTECH_LSP','Example Fintech','DRAFT',1,$AUD),($P2,$T_A,'NBFC','Other NBFC','DRAFT',1,$AUD);"

echo "== partner rules"
expect_error "LIVE partner without a business ID is rejected" "ck_partner_code_after_approval" "
UPDATE partner SET status='LIVE' WHERE id=$P1;"
expect_error "unknown partner type is rejected" "ck_partner_type" "
UPDATE partner SET partner_type='CRYPTO' WHERE id=$P1;"
expect_ok "PAN registered for P1" "
INSERT INTO partner_identifier (id,tenant_id,partner_id,id_type,id_value) VALUES (UUID_TO_BIN(UUID()),$T_A,$P1,'PAN','AAACX1234K');"
expect_error "same PAN for another partner is rejected (BR-01.01-01)" "uk_partner_identifier_active" "
INSERT INTO partner_identifier (id,tenant_id,partner_id,id_type,id_value) VALUES (UUID_TO_BIN(UUID()),$T_A,$P2,'PAN','AAACX1234K');"
expect_ok "same PAN in another tenant is allowed (tenant isolation)" "
INSERT INTO partner VALUES ($T_B,$T_B,NULL,'NBFC','Bank X originator','DRAFT',NULL,NULL,1,NULL,0,0,$AUD);
INSERT INTO partner_identifier (id,tenant_id,partner_id,id_type,id_value) VALUES (UUID_TO_BIN(UUID()),$T_B,$T_B,'PAN','AAACX1234K');"
expect_ok "after rejection the PAN is released and can be re-onboarded (BR-01.01-09)" "
UPDATE partner_identifier SET released_at=$NOW WHERE partner_id=$P1 AND id_type='PAN';
INSERT INTO partner_identifier (id,tenant_id,partner_id,id_type,id_value) VALUES (UUID_TO_BIN(UUID()),$T_A,$P2,'PAN','AAACX1234K');"

echo "== tenant isolation through composite foreign keys"
expect_error "program in tenant B pointing at tenant A's partner is rejected" "fk_program_partner" "
INSERT INTO program (id,tenant_id,partner_id,name,business_model,product_code,channel,latest_version,created_by,created_at,updated_by,updated_at)
VALUES (UUID_TO_BIN(UUID()),$T_B,$P1,'Cross-tenant','PARTNERSHIP_LENDING','PERSONAL_LOAN','API',1,$AUD);"

echo "== versions"
expect_ok "program and version 1 (ACTIVE) created" "
INSERT INTO program (id,tenant_id,partner_id,name,business_model,product_code,channel,latest_version,created_by,created_at,updated_by,updated_at)
VALUES ($PRG,$T_A,$P1,'Personal Loan - App','PARTNERSHIP_LENDING','PERSONAL_LOAN','API',2,$AUD);
INSERT INTO program_version (id,tenant_id,program_id,version,status,effective_from,content,change_request_id,created_by,created_at,updated_by,updated_at)
VALUES (UUID_TO_BIN(UUID()),$T_A,$PRG,1,'ACTIVE','2026-10-20 00:00:00','{\"links\":{\"ruleSet\":{\"ruleSetId\":\"RS-PL-STD\",\"version\":7},\"limitSetId\":\"0192eeee-0000-7000-8000-000000000001\"},\"policyException\":{\"flagged\":false}}',$CR2,$AUD);"
expect_error "a second ACTIVE version of the same program is rejected" "uk_program_version_active" "
INSERT INTO program_version (id,tenant_id,program_id,version,status,effective_from,content,change_request_id,created_by,created_at,updated_by,updated_at)
VALUES (UUID_TO_BIN(UUID()),$T_A,$PRG,2,'ACTIVE','2026-11-01 00:00:00','{}',$CR2,$AUD);"
expect_error "duplicate version number is rejected" "uk_program_version" "
INSERT INTO program_version (id,tenant_id,program_id,version,status,content,change_request_id,created_by,created_at,updated_by,updated_at)
VALUES (UUID_TO_BIN(UUID()),$T_A,$PRG,1,'DRAFT','{}',$CR2,$AUD);"
expect_ok "a SCHEDULED version 2 alongside the ACTIVE one is allowed" "
INSERT INTO program_version (id,tenant_id,program_id,version,status,effective_from,content,change_request_id,created_by,created_at,updated_by,updated_at)
VALUES (UUID_TO_BIN(UUID()),$T_A,$PRG,2,'SCHEDULED','2026-11-01 00:00:00','{\"links\":{\"ruleSet\":{\"ruleSetId\":\"RS-PL-STD\",\"version\":8}}}',$CR2,$AUD);"
expect_error "effective_to before effective_from is rejected" "ck_program_version_period" "
UPDATE program_version SET effective_to='2026-10-01 00:00:00' WHERE program_id=$PRG AND version=1;"
expect_error "content that is not a JSON object is rejected" "ck_program_version_content" "
INSERT INTO program_version (id,tenant_id,program_id,version,status,content,change_request_id,created_by,created_at,updated_by,updated_at)
VALUES (UUID_TO_BIN(UUID()),$T_A,$PRG,3,'DRAFT','[1,2]',$CR2,$AUD);"
expect_value "rule set is extracted from JSON content (ADR-0012)" "RS-PL-STD	7" "
SELECT rule_set_id, rule_set_version FROM program_version WHERE program_id=$PRG AND version=1;"
expect_index "'which programs use rule set RS-PL-STD v7' uses the index" "ix_program_version_rule_set" "
SELECT program_id FROM program_version WHERE tenant_id=$T_A AND rule_set_id='RS-PL-STD' AND rule_set_version=7;"
expect_ok "switching ACTIVE from v1 to v2 in one transaction works" "
START TRANSACTION;
UPDATE program_version SET status='SUPERSEDED', effective_to='2026-11-01 00:00:00' WHERE program_id=$PRG AND version=1;
UPDATE program_version SET status='ACTIVE' WHERE program_id=$PRG AND version=2;
COMMIT;"

echo "== maker-checker trigger"
expect_ok "approval steps created" "
INSERT INTO approval_step (id,change_request_id,sequence,role,step_tenant_id,status) VALUES
 (UUID_TO_BIN('0192ffff-0000-7000-8000-000000000001'),$CR1,1,'COMPLIANCE_OFFICER',$T_A,'PENDING'),
 (UUID_TO_BIN('0192ffff-0000-7000-8000-000000000002'),$CR1,2,'HEAD_OF_COMPLIANCE',$T_A,'WAITING');"
expect_error "maker approving their own request is rejected" "MAKER_CANNOT_APPROVE" "
UPDATE approval_step SET status='APPROVED', decided_by='priya', decided_at=$NOW WHERE sequence=1 AND change_request_id=$CR1;"
expect_ok "a different user approves step 1" "
UPDATE approval_step SET status='APPROVED', decided_by='arjun', decided_at=$NOW WHERE sequence=1 AND change_request_id=$CR1;"
expect_error "the same user approving step 2 is rejected" "APPROVER_ALREADY_DECIDED" "
UPDATE approval_step SET status='APPROVED', decided_by='arjun', decided_at=$NOW WHERE sequence=2 AND change_request_id=$CR1;"
expect_error "return without a comment is rejected" "ck_approval_step_comment" "
UPDATE approval_step SET status='RETURNED', decided_by='kavya', decided_at=$NOW WHERE sequence=2 AND change_request_id=$CR1;"

echo "== co-lending, DLG, credentials"
expect_ok "arrangement between tenant A and tenant B" "
INSERT INTO colending_arrangement (id,tenant_id,originating_lender_kind,originating_lender_id,co_lender_kind,co_lender_id,status,latest_version,created_by,created_at,updated_by,updated_at)
VALUES (UUID_TO_BIN('0192abab-0000-7000-8000-000000000001'),$T_A,'TENANT',$T_A,'TENANT',$T_B,'DRAFT',1,$AUD);"
expect_error "a lender cannot co-lend with itself" "ck_colending_distinct_lenders" "
INSERT INTO colending_arrangement (id,tenant_id,originating_lender_kind,originating_lender_id,co_lender_kind,co_lender_id,status,latest_version,created_by,created_at,updated_by,updated_at)
VALUES (UUID_TO_BIN(UUID()),$T_A,'TENANT',$T_A,'TENANT',$T_A,'DRAFT',1,$AUD);"
expect_error "arrangement version ACTIVE without escrow and core verification is rejected (C5)" "ck_arrangement_version_verified" "
INSERT INTO change_request (id,tenant_id,cr_code,type,aggregate_type,aggregate_id,status,summary,maker_user_id,created_by,created_at,updated_by,updated_at)
VALUES (UUID_TO_BIN('0192cccc-0000-7000-8000-000000000003'),$T_A,'CR-000003','ARRANGEMENT_VERSION','ARRANGEMENT',UUID_TO_BIN('0192abab-0000-7000-8000-000000000001'),'DRAFT','Arr v1','priya',$AUD);
INSERT INTO arrangement_version (id,tenant_id,arrangement_id,version,status,content,change_request_id,created_by,created_at,updated_by,updated_at)
VALUES (UUID_TO_BIN(UUID()),$T_A,UUID_TO_BIN('0192abab-0000-7000-8000-000000000001'),1,'ACTIVE','{}',UUID_TO_BIN('0192cccc-0000-7000-8000-000000000003'),$AUD);"
expect_error "DLG form outside the allowed list is rejected (BR-01.04-02)" "ck_dlg_cover_version_form" "
INSERT INTO dlg_cover (id,tenant_id,partner_id,latest_version,created_by,created_at,updated_by,updated_at) VALUES (UUID_TO_BIN('0192acac-0000-7000-8000-000000000001'),$T_A,$P1,1,$AUD);
INSERT INTO dlg_cover_version (id,tenant_id,dlg_cover_id,version,status,content,change_request_id,created_by,created_at,updated_by,updated_at)
VALUES (UUID_TO_BIN(UUID()),$T_A,UUID_TO_BIN('0192acac-0000-7000-8000-000000000001'),1,'DRAFT','{\"form\":\"CORPORATE_GUARANTEE\"}',$CR1,$AUD);"
expect_error "bank guarantee without an expiry date is rejected" "ck_dlg_instrument_expiry" "
INSERT INTO dlg_instrument (id,tenant_id,dlg_cover_id,form,reference_number,amount_paise,status,created_by,created_at,updated_by,updated_at)
VALUES (UUID_TO_BIN(UUID()),$T_A,UUID_TO_BIN('0192acac-0000-7000-8000-000000000001'),'BANK_GUARANTEE','BG-1',100000000,'RECORDED',$AUD);"
expect_error "non-HTTPS webhook URL is rejected" "ck_api_client_webhook_https" "
INSERT INTO api_client (id,tenant_id,partner_id,environment,status,scopes,rate_limit_per_second,rate_limit_per_day,ip_allow_list,webhook_url,created_by,created_at,updated_by,updated_at)
VALUES (UUID_TO_BIN(UUID()),$T_A,$P1,'SANDBOX','REQUESTED','[]',5,300000,'[]','http://partner.example/hook',$AUD);"

echo "== audit log"
expect_ok "first audit record (seq 1, zero previous hash)" "
INSERT INTO audit_record (id,tenant_id,aggregate_type,aggregate_id,aggregate_seq,occurred_at,actor,action,previous_hash,hash)
VALUES (UUID_TO_BIN(UUID()),$T_A,'PARTNER',$P1,1,$NOW,'priya','CREATED',REPEAT('0',64),SHA2('r1',256));"
expect_error "a record with the wrong previous hash is rejected" "AUDIT_CHAIN_BROKEN" "
INSERT INTO audit_record (id,tenant_id,aggregate_type,aggregate_id,aggregate_seq,occurred_at,actor,action,previous_hash,hash)
VALUES (UUID_TO_BIN(UUID()),$T_A,'PARTNER',$P1,2,$NOW,'priya','UPDATED',SHA2('forged',256),SHA2('r2',256));"
expect_ok "a correctly chained record is accepted" "
INSERT INTO audit_record (id,tenant_id,aggregate_type,aggregate_id,aggregate_seq,occurred_at,actor,action,previous_hash,hash)
VALUES (UUID_TO_BIN(UUID()),$T_A,'PARTNER',$P1,2,$NOW,'priya','UPDATED',SHA2('r1',256),SHA2('r2',256));"
expect_error "audit records cannot be updated" "AUDIT_RECORD_IMMUTABLE" "UPDATE audit_record SET actor='mallory';"
expect_error "audit records cannot be deleted" "AUDIT_RECORD_IMMUTABLE" "DELETE FROM audit_record;"

echo "== packages and outbox"
expect_ok "first application of a package" "
INSERT INTO config_import (id,tenant_id,package_sha256,signature_valid,status,diff,validation,document_id,created_by,created_at)
VALUES (UUID_TO_BIN(UUID()),$T_A,SHA2('pkg',256),TRUE,'APPLIED','[]','{}','doc-1','sam',$NOW);"
expect_error "applying the same package twice is rejected (ADR-0010)" "uk_config_import_applied" "
INSERT INTO config_import (id,tenant_id,package_sha256,signature_valid,status,diff,validation,document_id,created_by,created_at)
VALUES (UUID_TO_BIN(UUID()),$T_A,SHA2('pkg',256),TRUE,'APPLIED','[]','{}','doc-2','sam',$NOW);"
expect_error "an unsigned package cannot be applied" "ck_config_import_signed" "
INSERT INTO config_import (id,tenant_id,package_sha256,signature_valid,status,diff,validation,document_id,created_by,created_at)
VALUES (UUID_TO_BIN(UUID()),$T_A,SHA2('pkg2',256),FALSE,'APPLIED','[]','{}','doc-3','sam',$NOW);"
expect_error "two outbox messages with the same revision for one aggregate are rejected" "uk_outbox_event_revision" "
INSERT INTO outbox_event VALUES (UUID_TO_BIN(UUID()),$T_A,'PROGRAM','p1','npos.partner-config.program.v1','com.npos.partnerconfig.program.snapshot.v1',1,'{}','{}',$NOW),
                                (UUID_TO_BIN(UUID()),$T_A,'PROGRAM','p1','npos.partner-config.program.v1','com.npos.partnerconfig.program.snapshot.v1',1,'{}','{}',$NOW);"

echo
echo "passed: $PASS  failed: $FAIL"
[[ $FAIL -eq 0 ]]
