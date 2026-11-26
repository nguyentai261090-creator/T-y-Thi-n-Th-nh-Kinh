-- ============================================================================
-- FILE: TEST_CASE_INDEX_FIXED.sql
-- Database: real_estate_ledger
-- Purpose: Compare each of the 7 secondary indexes with an index-disabled run.
-- Run INDEX_FIXED.sql first.
-- Uses FORCE INDEX / IGNORE INDEX so the two plans are explicit and comparable.
-- ============================================================================

USE real_estate_ledger;

-- Select existing sample values so the test does not depend on hard-coded IDs.
SET @tc02_property_id := COALESCE(
    (SELECT property_id FROM LEASE_CONTRACT WHERE contract_status = 'Active' LIMIT 1),
    (SELECT property_id FROM LEASE_CONTRACT LIMIT 1)
);

SET @tc03_tenant_id := (SELECT tenant_id FROM LEASE_CONTRACT LIMIT 1);

SET @tc04_property_id := (SELECT property_id FROM FINANCIAL_LEDGER LIMIT 1);

SET @tc05_payer_id := (SELECT payer_id FROM FINANCIAL_LEDGER LIMIT 1);
SET @tc05_payee_id := (
    SELECT payee_id FROM FINANCIAL_LEDGER
    WHERE payer_id = @tc05_payer_id
    LIMIT 1
);

SET @tc06_payee_id := (SELECT payee_id FROM FINANCIAL_LEDGER LIMIT 1);

SET @tc07_property_id := (SELECT property_id FROM MAINTENANCE_REQUEST LIMIT 1);
SET @tc07_status := (
    SELECT request_status FROM MAINTENANCE_REQUEST
    WHERE property_id = @tc07_property_id
    LIMIT 1
);

-- ---------------------------------------------------------------------------
-- TC01: PROPERTY by current_state and rental_price
-- Expected index: idx_property_state_price
-- ---------------------------------------------------------------------------
SELECT 'TC01 - PROPERTY - FORCE INDEX' AS test_case;
EXPLAIN ANALYZE
SELECT property_id, title, current_state, rental_price
FROM PROPERTY FORCE INDEX (idx_property_state_price)
WHERE current_state = 'Available'
  AND rental_price BETWEEN 10000000 AND 30000000
ORDER BY rental_price;

SELECT 'TC01 - PROPERTY - IGNORE INDEX' AS test_case;
EXPLAIN ANALYZE
SELECT property_id, title, current_state, rental_price
FROM PROPERTY IGNORE INDEX (idx_property_state_price)
WHERE current_state = 'Available'
  AND rental_price BETWEEN 10000000 AND 30000000
ORDER BY rental_price;

-- ---------------------------------------------------------------------------
-- TC02: LEASE_CONTRACT by property and contract status
-- Expected index: idx_lease_property_status
-- ---------------------------------------------------------------------------
SELECT 'TC02 - LEASE_CONTRACT property/status - FORCE INDEX' AS test_case;
EXPLAIN ANALYZE
SELECT contract_id, property_id, tenant_id, contract_status
FROM LEASE_CONTRACT FORCE INDEX (idx_lease_property_status)
WHERE property_id = @tc02_property_id
  AND contract_status = 'Active';

SELECT 'TC02 - LEASE_CONTRACT property/status - IGNORE INDEX' AS test_case;
EXPLAIN ANALYZE
SELECT contract_id, property_id, tenant_id, contract_status
FROM LEASE_CONTRACT IGNORE INDEX (idx_lease_property_status)
WHERE property_id = @tc02_property_id
  AND contract_status = 'Active';

-- ---------------------------------------------------------------------------
-- TC03: LEASE_CONTRACT by tenant and date range
-- Expected index: idx_lease_tenant_dates
-- ---------------------------------------------------------------------------
SELECT 'TC03 - LEASE_CONTRACT tenant/dates - FORCE INDEX' AS test_case;
EXPLAIN ANALYZE
SELECT contract_id, tenant_id, property_id, start_date, end_date
FROM LEASE_CONTRACT FORCE INDEX (idx_lease_tenant_dates)
WHERE tenant_id = @tc03_tenant_id
  AND start_date >= '1900-01-01'
  AND start_date < '2101-01-01'
ORDER BY start_date, end_date;

SELECT 'TC03 - LEASE_CONTRACT tenant/dates - IGNORE INDEX' AS test_case;
EXPLAIN ANALYZE
SELECT contract_id, tenant_id, property_id, start_date, end_date
FROM LEASE_CONTRACT IGNORE INDEX (idx_lease_tenant_dates)
WHERE tenant_id = @tc03_tenant_id
  AND start_date >= '1900-01-01'
  AND start_date < '2101-01-01'
ORDER BY start_date, end_date;

-- ---------------------------------------------------------------------------
-- TC04: FINANCIAL_LEDGER by property and transaction date
-- Expected index: idx_ledger_property_created
-- ---------------------------------------------------------------------------
SELECT 'TC04 - FINANCIAL_LEDGER property/date - FORCE INDEX' AS test_case;
EXPLAIN ANALYZE
SELECT ledger_id, property_id, amount, created_at
FROM FINANCIAL_LEDGER FORCE INDEX (idx_ledger_property_created)
WHERE property_id = @tc04_property_id
  AND created_at >= '1900-01-01'
  AND created_at < '2101-01-01'
ORDER BY created_at;

SELECT 'TC04 - FINANCIAL_LEDGER property/date - IGNORE INDEX' AS test_case;
EXPLAIN ANALYZE
SELECT ledger_id, property_id, amount, created_at
FROM FINANCIAL_LEDGER IGNORE INDEX (idx_ledger_property_created)
WHERE property_id = @tc04_property_id
  AND created_at >= '1900-01-01'
  AND created_at < '2101-01-01'
ORDER BY created_at;

-- ---------------------------------------------------------------------------
-- TC05: FINANCIAL_LEDGER by payer and payee
-- Expected index: idx_ledger_payer_payee
-- ---------------------------------------------------------------------------
SELECT 'TC05 - FINANCIAL_LEDGER payer/payee - FORCE INDEX' AS test_case;
EXPLAIN ANALYZE
SELECT ledger_id, payer_id, payee_id, amount, created_at
FROM FINANCIAL_LEDGER FORCE INDEX (idx_ledger_payer_payee)
WHERE payer_id = @tc05_payer_id
  AND payee_id = @tc05_payee_id
  AND created_at >= '1900-01-01'
  AND created_at < '2101-01-01'
ORDER BY created_at;

SELECT 'TC05 - FINANCIAL_LEDGER payer/payee - IGNORE INDEX'
AS test_case;

EXPLAIN ANALYZE
SELECT
    ledger_id,
    payer_id,
    payee_id,
    amount,
    created_at
FROM FINANCIAL_LEDGER
IGNORE INDEX (
    idx_ledger_payer_payee,
    idx_ledger_payee_created
)
WHERE payer_id = @tc05_payer_id
  AND payee_id = @tc05_payee_id
  AND created_at >= '1900-01-01'
  AND created_at < '2101-01-01'
ORDER BY created_at;

SELECT 'TC06 - FINANCIAL_LEDGER payee/date - IGNORE INDEX' AS test_case;
EXPLAIN ANALYZE
SELECT ledger_id, payee_id, payer_id, amount, created_at
FROM FINANCIAL_LEDGER IGNORE INDEX (idx_ledger_payee_created)
WHERE payee_id = @tc06_payee_id
  AND created_at >= '1900-01-01'
  AND created_at < '2101-01-01'
ORDER BY created_at;

-- ---------------------------------------------------------------------------
-- TC07: MAINTENANCE_REQUEST by property and request status
-- Expected index: idx_maint_property_status
-- ---------------------------------------------------------------------------
SELECT 'TC07 - MAINTENANCE_REQUEST property/status - FORCE INDEX' AS test_case;
EXPLAIN ANALYZE
SELECT request_id, property_id, tenant_id, request_status, created_at
FROM MAINTENANCE_REQUEST FORCE INDEX (idx_maint_property_status)
WHERE property_id = @tc07_property_id
  AND request_status = @tc07_status
ORDER BY created_at DESC;

SELECT 'TC07 - MAINTENANCE_REQUEST property/status - IGNORE INDEX' AS test_case;
EXPLAIN ANALYZE
SELECT request_id, property_id, tenant_id, request_status, created_at
FROM MAINTENANCE_REQUEST IGNORE INDEX (idx_maint_property_status)
WHERE property_id = @tc07_property_id
  AND request_status = @tc07_status
ORDER BY created_at DESC;

-- ---------------------------------------------------------------------------
-- TC08: Financial summary View (integrated query; no direct index pair)
-- ---------------------------------------------------------------------------
SELECT 'TC08 - FINANCIAL SUMMARY VIEW' AS test_case;
EXPLAIN ANALYZE
SELECT *
FROM vw_property_financial_summary
WHERE net_cashflow > 50000000
ORDER BY net_cashflow DESC
LIMIT 20;
