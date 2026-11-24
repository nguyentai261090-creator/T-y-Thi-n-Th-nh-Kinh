-- ============================================================================
-- FILE: TEST_CASE_INDEX.sql
-- ============================================================================

USE real_estate_ledger;

-- Test case 1: Tìm bất động sản theo trạng thái và giá thuê 
EXPLAIN ANALYZE
SELECT
    property_id,
    current_state,
    rental_price,
    property_type,
    city
FROM PROPERTY
WHERE current_state = 'Available'
  AND rental_price BETWEEN 10000000 AND 30000000
ORDER BY rental_price;

EXPLAIN ANALYZE
SELECT
    property_id,
    current_state,
    rental_price,
    property_type,
    city
FROM PROPERTY IGNORE INDEX (idx_property_state_price)
WHERE current_state = 'Available'
  AND rental_price BETWEEN 10000000 AND 30000000
ORDER BY rental_price;

-- Test case 2: Tra cứu hợp đồng theo bất động sản
EXPLAIN ANALYZE
SELECT
    contract_id,
    property_id,
    tenant_id,
    contract_status
FROM LEASE_CONTRACT
WHERE property_id = 100
  AND contract_status = 'Active';

EXPLAIN ANALYZE
SELECT
    contract_id,
    property_id,
    tenant_id,
    contract_status
FROM LEASE_CONTRACT IGNORE INDEX (idx_lease_property_status)
WHERE property_id = 100
  AND contract_status = 'Active';

-- Test case 3: Tra cứu sổ cái tài chính
EXPLAIN ANALYZE
SELECT
    ledger_id,
    property_id,
    amount,
    created_at
FROM FINANCIAL_LEDGER
WHERE property_id = 100
  AND created_at >= '2026-01-01'
  AND created_at < '2027-01-01'
ORDER BY created_at;

EXPLAIN ANALYZE
SELECT
    ledger_id,
    property_id,
    amount,
    created_at
FROM FINANCIAL_LEDGER IGNORE INDEX (idx_ledger_property_created)
WHERE property_id = 100
  AND created_at >= '2026-01-01'
  AND created_at < '2027-01-01'
ORDER BY created_at;

-- Test case 4: Kiểm thử View báo cáo tài chính
EXPLAIN ANALYZE
SELECT *
FROM vw_property_financial_summary
WHERE net_cashflow > 50000000
ORDER BY net_cashflow DESC
LIMIT 20;