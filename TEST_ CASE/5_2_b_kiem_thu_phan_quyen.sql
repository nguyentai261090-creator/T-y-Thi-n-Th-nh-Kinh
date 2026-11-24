-- =========================================================================
-- DE TAI: #10 Real Estate Property & Rental Ledger
-- MUC 5.2 (KIEM THU): CHUNG MINH RBAC CHAN DUNG NGUOI, CHO DUNG VIEC
-- =========================================================================
-- CACH CHAY: tao 5 ket noi (connection) rieng trong MySQL Workbench, moi ket noi
-- dang nhap bang MOT tai khoan demo (mat khau xem 5_2_rbac.sql, BUOC 4).
-- Voi moi tai khoan, chay tung khoi lenh duoi tieu de cua tai khoan do
-- (Execute Selection - Ctrl+Shift+Enter). Cac test ket thuc bang ROLLBACK
-- khong de lai du lieu thua.
-- Ma loi mong doi:
--   1142 = <lenh> command denied ... for table  (khong co quyen tren bang/view)
--   1143 = <lenh> command denied ... for column (khong co quyen tren cot)
--   1369 = CHECK OPTION failed (ghi sai hang cua view)
-- Ten bang trong thong bao loi co the viet thuong tuy he dieu hanh; khong anh huong.
-- TRANG THAI: chua duoc chay thu tren MySQL trong moi truong soan thao.
-- =========================================================================

-- =========================================================================
-- TAI KHOAN admin_1  (role_admin)
-- =========================================================================
USE real_estate_ledger;

-- A1 | Admin doc duoc so cai (audit trail)   | Mong doi: 10000 (neu da nap du lieu mau)
SELECT COUNT(*) AS so_dong_so_cai FROM FINANCIAL_LEDGER;

-- A2 | Admin KHONG sua duoc so cai: bi chan o lop QUYEN truoc khi toi trigger
-- Mong doi: ERROR 1142 - UPDATE command denied to user 'admin_1'@'localhost'
UPDATE FINANCIAL_LEDGER SET amount = 1 WHERE ledger_id = 1;

-- A3 | Admin KHONG xoa duoc dong so cai | Mong doi: ERROR 1142 - DELETE command denied
DELETE FROM FINANCIAL_LEDGER WHERE ledger_id = 1;

-- A4 | Admin KHONG doi trang thai tai san (tach nhiem vu voi Property Manager)
-- Mong doi: ERROR 1142 - UPDATE command denied
UPDATE PROPERTY SET current_state = 'Available' WHERE property_id = 1100;

-- A5 | Admin duoc chay DDL (them/xoa chi muc thu) | Mong doi: thanh cong
CREATE INDEX idx_tmp_title ON PROPERTY (title(50));
DROP INDEX idx_tmp_title ON PROPERTY;

-- =========================================================================
-- TAI KHOAN manager_16  (role_property_manager)
-- =========================================================================
USE real_estate_ledger;

-- M1 | Quan ly doi trang thai nha (cot current_state)  | Mong doi: thanh cong (roi hoan tac)
START TRANSACTION;
UPDATE PROPERTY SET current_state = 'Available' WHERE property_id = 1100;
SELECT property_id, current_state FROM PROPERTY WHERE property_id = 1100;
ROLLBACK;

-- M2 | Quan ly KHONG duoc sua gia thue (quyen o muc COT)
-- Mong doi: ERROR 1143 - UPDATE command denied ... for column 'rental_price'
UPDATE PROPERTY SET rental_price = 1000000 WHERE property_id = 1100;

-- M3 | Quan ly KHONG tu dang tin nha moi (BR1: chi chu nha uy quyen)
-- Mong doi: ERROR 1142 - INSERT command denied
INSERT INTO PROPERTY (landlord_id, title, address, current_state, rental_price)
VALUES (251, 'Nha kiem thu', '1 Duong Kiem Thu', 'Available', 9000000.00);

-- M4 | Quan ly KHONG sua / xoa duoc so cai | Mong doi: ERROR 1142 (ca hai lenh)
UPDATE FINANCIAL_LEDGER SET amount = 1 WHERE ledger_id = 1;
DELETE FROM FINANCIAL_LEDGER WHERE ledger_id = 1;

-- M5 | Quan ly duyet hop dong Draft -> Active: trigger tu doi trang thai nha va ghi so cai
-- (trigger chay voi quyen cua nguoi tao trigger nen manager khong can quyen ghi so cai cho buoc nay)
-- Hop dong 1801: Draft, can 652 (Available), moi gioi 102, khach 602.
-- Mong doi: thanh cong; can 652 = 'Leased'; 2 dong so cai moi (Deposit + Agent_Commission).
START TRANSACTION;
UPDATE LEASE_CONTRACT SET contract_status = 'Active' WHERE contract_id = 1801;
SELECT property_id, current_state FROM PROPERTY WHERE property_id = 652;
SELECT category, transaction_type, amount
FROM FINANCIAL_LEDGER
WHERE related_contract_id = 1801
ORDER BY ledger_id DESC
LIMIT 2;
ROLLBACK;

-- =========================================================================
-- TAI KHOAN agent_102  (role_agent)
-- =========================================================================
USE real_estate_ledger;

-- G1 | Moi gioi xem duoc nha trong | Mong doi: 550
SELECT COUNT(*) AS so_nha_trong FROM vw_available_properties;

-- G2 | Moi gioi KHONG doc duoc bang goc PROPERTY / so cai
-- Mong doi: ERROR 1142 - SELECT command denied (ca hai lenh)
SELECT * FROM PROPERTY LIMIT 1;
SELECT * FROM FINANCIAL_LEDGER LIMIT 1;

-- G3 | Moi gioi chi thay hop dong cua chinh minh | Mong doi: 10
SELECT COUNT(*) AS so_hop_dong_cua_toi FROM vw_agent_contracts;

-- G4 | Moi gioi tao hop dong NHAP cho chinh minh | Mong doi: thanh cong, contract_status = 'Draft'
START TRANSACTION;
INSERT INTO vw_agent_contracts
    (property_id, tenant_id, agent_id, start_date, end_date,
     monthly_rent, deposit_amount, commission_rate)
VALUES
    (705, 605, 102, '2027-01-01', '2028-01-01', 12000000.00, 24000000.00, 5.00);
SELECT contract_id, agent_id, contract_status
FROM vw_agent_contracts
ORDER BY contract_id DESC
LIMIT 1;
ROLLBACK;

-- G5 | Moi gioi KHONG tao hop dong mang ten moi gioi khac
-- Mong doi: ERROR 1369 - CHECK OPTION failed 'real_estate_ledger.vw_agent_contracts'
INSERT INTO vw_agent_contracts
    (property_id, tenant_id, agent_id, start_date, end_date,
     monthly_rent, deposit_amount, commission_rate)
VALUES
    (705, 605, 103, '2027-01-01', '2028-01-01', 12000000.00, 24000000.00, 5.00);

-- G6 | Moi gioi KHONG tu dat hop dong thanh Active ngay luc tao
-- Mong doi: ERROR 1143 - INSERT command denied ... for column 'contract_status'
INSERT INTO vw_agent_contracts
    (property_id, tenant_id, agent_id, start_date, end_date,
     monthly_rent, deposit_amount, commission_rate, contract_status)
VALUES
    (705, 605, 102, '2027-01-01', '2028-01-01', 12000000.00, 24000000.00, 5.00, 'Active');

-- G7 | Moi gioi KHONG duyet duoc hop dong | Mong doi: ERROR 1142/1143 - UPDATE command denied
UPDATE vw_agent_contracts SET contract_status = 'Active' WHERE contract_id = 1;

-- =========================================================================
-- TAI KHOAN tenant_601  (role_tenant)
-- =========================================================================
USE real_estate_ledger;

-- T1 | Khach chi thay hop dong cua minh | Mong doi: 2 (hop dong 900 va 1800)
SELECT COUNT(*) AS so_hop_dong FROM vw_tenant_my_contracts;

-- T2 | Khach chi thay lich su dong tien minh da tra | Mong doi: 5
SELECT COUNT(*) AS so_khoan_da_tra FROM vw_tenant_my_payments;

-- T3 | Khach KHONG doc duoc bang goc | Mong doi: ERROR 1142 - SELECT command denied
SELECT * FROM LEASE_CONTRACT LIMIT 1;

-- T4 | Khach gui phieu bao tri cua minh | Mong doi: thanh cong, request_status = 'Pending'
START TRANSACTION;
INSERT INTO vw_tenant_maintenance (property_id, tenant_id, description)
VALUES (900, 601, 'Hong voi nuoc nha ve sinh');
SELECT request_id, tenant_id, request_status
FROM vw_tenant_maintenance
ORDER BY request_id DESC
LIMIT 1;
ROLLBACK;

-- T5 | Khach KHONG gui phieu mao danh khach khac
-- Mong doi: ERROR 1369 - CHECK OPTION failed 'real_estate_ledger.vw_tenant_maintenance'
INSERT INTO vw_tenant_maintenance (property_id, tenant_id, description)
VALUES (900, 602, 'Phieu mao danh');

-- T6 | Khach KHONG tu dat trang thai phieu | Mong doi: ERROR 1143 - INSERT command denied ... for column
INSERT INTO vw_tenant_maintenance (property_id, tenant_id, description, request_status)
VALUES (900, 601, 'Tu duyet phieu', 'Completed');

-- T7 | Khach KHONG xem duoc so cai tong | Mong doi: ERROR 1142 - SELECT command denied
SELECT * FROM FINANCIAL_LEDGER LIMIT 1;

-- =========================================================================
-- TAI KHOAN landlord_251  (role_landlord)
-- =========================================================================
USE real_estate_ledger;

-- L1 | Chu nha chi thay nha cua minh | Mong doi: 3 (can 380, 760, 1140)
SELECT property_id, title, current_state FROM vw_landlord_my_properties;

-- L2 | Bao cao thu/chi cua nha minh | Mong doi: 3 dong (moi can mot dong)
SELECT property_id, total_income, total_expense, net_cashflow
FROM vw_landlord_my_financials
ORDER BY net_cashflow DESC;

-- L3 | Chu nha KHONG doc duoc bang goc | Mong doi: ERROR 1142 - SELECT command denied
SELECT * FROM PROPERTY LIMIT 1;

-- L4 | Chu nha KHONG sua duoc gia thue qua view | Mong doi: ERROR 1142/1143 - UPDATE command denied
UPDATE vw_landlord_my_properties SET rental_price = 1 WHERE property_id = 380;

-- L5 | Chu nha KHONG xem duoc nha cua chu khac (ham loc hang theo tai khoan)
-- Mong doi: 0 dong
SELECT * FROM vw_landlord_my_properties WHERE property_id = 1;
w