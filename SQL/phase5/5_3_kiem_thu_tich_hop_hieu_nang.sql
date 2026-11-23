-- =========================================================================
-- DE TAI: #10 Real Estate Property & Rental Ledger
-- NHOM THUC HIEN: Tay Thien Thinh Kinh
-- MUC 5.3: INTEGRATION TESTING - KICH BAN VONG DOI CHO THUE + HIEU NANG
-- =========================================================================
-- CACH CHAY: dang nhap bang tai khoan root (hoac Admin DB). Boi den TUNG KICH BAN
-- (tu START TRANSACTION den ROLLBACK) roi Execute Selection (Ctrl+Shift+Enter).
-- Kich ban chay tron ven trong mot giao dich va ROLLBACK o cuoi, nen khong de lai du lieu.
-- Phan DB nay mo phong dung thao tac cua tung vai tro tren giao dien web (muc 4.4);
-- khi demo that, thuc hien lai tren web va doi chieu bang cac cau SELECT trong kich ban.
-- TRANG THAI: chua duoc chay thu tren MySQL trong moi truong soan thao.
-- =========================================================================

USE real_estate_ledger;

-- -------------------------------------------------------------------------
-- KICH BAN S1: VONG DOI DAY DU CUA MOT CAN NHA
--   Moi gioi tao hop dong Draft -> Manager duyet (Active) -> khach tra tien thue
--   -> khach bao hong -> Manager duyet, nha Under Maintenance -> hoan tat sua
--   -> chi phi vao so cai, nha ve Available -> Chu nha xem bao cao thu/chi.
-- Du lieu dung: can 706 (Available, chu nha = user 577), khach 610, moi gioi 102,
--               Property Manager 16.
-- Ky vong tong ket cho rieng cac dong phat sinh trong kich ban:
--   thu = 20.000.000 (coc) + 10.000.000 (thue) = 30.000.000
--   chi =    500.000 (hoa hong) + 1.500.000 (bao tri) = 2.000.000
--   rong = 28.000.000
-- -------------------------------------------------------------------------
START TRANSACTION;

-- B1. Moi gioi xem nha trong (can 706 phai co mat trong danh sach)
SELECT property_id, property_title, rental_price
FROM vw_available_properties
WHERE property_id = 706;

-- B2. Moi gioi 102 tao hop dong NHAP gan voi khach 610 (hoa hong 5%)
INSERT INTO LEASE_CONTRACT
    (property_id, tenant_id, agent_id, start_date, end_date,
     monthly_rent, deposit_amount, commission_rate)
VALUES
    (706, 610, 102, '2027-01-01', '2028-01-01', 10000000.00, 20000000.00, 5.00);
SET @contract_id = LAST_INSERT_ID();
SELECT contract_id, contract_status FROM LEASE_CONTRACT WHERE contract_id = @contract_id;
-- Mong doi: contract_status = 'Draft'

-- B3. Manager duyet hop dong -> trigger doi trang thai nha va ghi coc + hoa hong
UPDATE LEASE_CONTRACT
SET contract_status = 'Active'
WHERE contract_id = @contract_id;
SELECT property_id, current_state FROM PROPERTY WHERE property_id = 706;
-- Mong doi: 'Leased'
SELECT transaction_type, category, amount
FROM FINANCIAL_LEDGER
WHERE related_contract_id = @contract_id
ORDER BY ledger_id;
-- Mong doi: INCOME Deposit 20000000.00 va EXPENSE Agent_Commission 500000.00

-- B4. Khach tra tien thue thang dau (chu nha = user 577)
INSERT INTO FINANCIAL_LEDGER
    (property_id, payer_id, payee_id, related_contract_id,
     transaction_type, category, amount)
VALUES
    (706, 610, 577, @contract_id, 'INCOME', 'Rent_Payment', 10000000.00);

-- B5. Khach bao hong: phieu bao tri o trang thai mac dinh 'Pending'
INSERT INTO MAINTENANCE_REQUEST (property_id, tenant_id, description)
VALUES (706, 610, 'Sua ro ri duong ong nuoc nha ve sinh');
SET @request_id = LAST_INSERT_ID();
SELECT request_id, request_status FROM MAINTENANCE_REQUEST WHERE request_id = @request_id;
-- Mong doi: 'Pending'

-- B6. Manager duyet phieu, giao cho minh va chuyen nha sang Under Maintenance
UPDATE MAINTENANCE_REQUEST
SET request_status = 'Approved',
    assigned_manager_id = 16,
    estimated_cost = 1350000.00
WHERE request_id = @request_id;
UPDATE PROPERTY
SET current_state = 'Under Maintenance'
WHERE property_id = 706;
INSERT INTO PROPERTY_STATE_HISTORY
    (property_id, changed_by, old_state, new_state, change_reason)
VALUES
    (706, 16, 'Leased', 'Under Maintenance', 'Tiep nhan su co ro ri duong ong nuoc');

-- B7. Sua xong: quyet toan chi phi, ghi so cai, tra nha ve Available
UPDATE MAINTENANCE_REQUEST
SET request_status = 'Completed',
    actual_cost = 1500000.00,
    resolved_at = NOW()
WHERE request_id = @request_id;
INSERT INTO FINANCIAL_LEDGER
    (property_id, payer_id, payee_id, related_request_id,
     transaction_type, category, amount)
VALUES
    (706, 577, 610, @request_id, 'EXPENSE', 'Maintenance_Cost', 1500000.00);
UPDATE PROPERTY
SET current_state = 'Available'
WHERE property_id = 706;
INSERT INTO PROPERTY_STATE_HISTORY
    (property_id, changed_by, old_state, new_state, change_reason)
VALUES
    (706, 16, 'Under Maintenance', 'Available', 'Nghiem thu hoan tat sua chua');

-- B8. Doi chieu thu / chi / rong cua rieng cac dong phat sinh trong kich ban nay
SELECT
    SUM(CASE WHEN transaction_type = 'INCOME'  THEN amount ELSE 0 END) AS tong_thu,
    SUM(CASE WHEN transaction_type = 'EXPENSE' THEN amount ELSE 0 END) AS tong_chi,
    SUM(CASE WHEN transaction_type = 'INCOME'  THEN amount ELSE -amount END) AS rong
FROM FINANCIAL_LEDGER
WHERE related_contract_id = @contract_id
   OR related_request_id  = @request_id;
-- Mong doi: 30000000.00 | 2000000.00 | 28000000.00

-- B9. Chu nha xem bao cao tong hop (so lieu cua can 706 gom ca du lieu mau cu)
SELECT property_id, total_transactions, total_income, total_expense, net_cashflow
FROM vw_property_financial_summary
WHERE property_id = 706;

-- B10. Nhat ky trang thai cua can 706 co 2 dong moi, khong dong nao bi ghi de
SELECT history_id, old_state, new_state, change_reason
FROM PROPERTY_STATE_HISTORY
WHERE property_id = 706
ORDER BY history_id DESC
LIMIT 2;

ROLLBACK;

-- -------------------------------------------------------------------------
-- KICH BAN S2: LUONG LOI PHAI QUAY LUI (ACID - Atomicity)
-- Kich hoat hop dong tren can dang Leased thi toan bo bi tu choi, khong de lai gi.
-- (Da co trong 5_1_constraint_tests.sql, T21; chay lai de doi chieu so cai khong doi.)
-- -------------------------------------------------------------------------
SELECT COUNT(*) AS so_dong_so_cai_truoc FROM FINANCIAL_LEDGER;
START TRANSACTION;
INSERT INTO LEASE_CONTRACT
    (property_id, tenant_id, agent_id, start_date, end_date,
     monthly_rent, deposit_amount, commission_rate)
VALUES
    (1, 602, 102, '2027-01-01', '2028-01-01', 10000000.00, 20000000.00, 5.00);
SET @contract_id = LAST_INSERT_ID();
UPDATE LEASE_CONTRACT SET contract_status = 'Active' WHERE contract_id = @contract_id;
-- Mong doi: ERROR 1644 VI PHAM BR2
ROLLBACK;
SELECT COUNT(*) AS so_dong_so_cai_sau FROM FINANCIAL_LEDGER;
-- Mong doi: hai gia tri bang nhau (10000)

-- -------------------------------------------------------------------------
-- KICH BAN S3: HIEU NANG - MUC TIEU SO-04 (< 200 ms) VA VIEC DUNG CHI MUC
-- Doc cot "actual time" trong ket qua EXPLAIN ANALYZE (bam nut "Wrap Cell Content").
-- -------------------------------------------------------------------------

-- P1. Tim nha trong theo khung gia -> mong doi dung idx_property_state_price
EXPLAIN
SELECT property_id, title, rental_price
FROM PROPERTY
WHERE current_state = 'Available'
  AND rental_price BETWEEN 10000000 AND 20000000;

-- P2. Kiem tra hop dong Active cua mot can (BR4) -> mong doi dung idx_lease_property_status
EXPLAIN
SELECT contract_id
FROM LEASE_CONTRACT
WHERE property_id = 701
  AND contract_status = 'Active';

-- P3. Doi soat dong tien theo can va thoi gian -> mong doi dung idx_ledger_property_created
EXPLAIN
SELECT ledger_id, category, amount, created_at
FROM FINANCIAL_LEDGER
WHERE property_id = 1
  AND created_at >= '2026-01-01'
ORDER BY created_at;

-- P4. Truy van tong hop tren 10.000 dong so cai (nhu DATA_AGGREGATION.sql, buoc 4)
EXPLAIN ANALYZE
SELECT *
FROM vw_property_financial_summary
WHERE net_cashflow > 50000000
ORDER BY net_cashflow DESC
LIMIT 20;
