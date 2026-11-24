-- =========================================================================
-- DE TAI: #10 Real Estate Property & Rental Ledger
-- NHOM THUC HIEN: Tay Thien Thinh Kinh
-- MUC 5.1: DATA INTEGRITY & CONSTRAINT VERIFICATION
-- =========================================================================
-- CACH CHAY (QUAN TRONG):
--   * Chay SAU KHI da chay du 6 file: DDL, INDEX, VIEWS, TRIGGERS, DATA_INSERTION.
--   * Moi test case la mot KHOI rieng. Boi den tung khoi roi bam
--     "Execute Selection" (Ctrl+Shift+Enter) trong MySQL Workbench.
--     Khong chay ca file mot lan: cac test CO CHU Y gay loi nen Workbench se dung.
--   * Cac test co BEGIN ... ROLLBACK khong de lai du lieu thua.
--   * Ma loi mong doi (MySQL 8.0.16+):
--       3819 = CHECK constraint bi vi pham      1062 = trung khoa UNIQUE/PK
--       1048 = cot NOT NULL nhan NULL            1452 = FK: khong co dong cha
--       1451 = FK: con dong con tham chieu (RESTRICT)
--       1644 = SIGNAL SQLSTATE '45000' tu TRIGGER
-- TRANG THAI: Script chua duoc chay thu tren MySQL trong moi truong soan thao.
--             Ban chay that va chup man hinh ket qua vao bao cao.
-- =========================================================================

USE real_estate_ledger;

-- -------------------------------------------------------------------------
-- NHOM A. RANG BUOC MIEN GIA TRI (CHECK / UNIQUE / NOT NULL)
-- Du lieu mau: PROPERTY 1..500 = Leased, 501..1050 = Available,
--              1051..1200 = Under Maintenance; TENANT = user 601..1500;
--              LANDLORD = user 251..650; AGENT = user 101..300.
-- -------------------------------------------------------------------------

-- T01 | BR4 | Ngay ket thuc phai lon hon ngay bat dau
-- Mong doi: ERROR 3819 - Check constraint 'chk_contract_dates' is violated.
INSERT INTO LEASE_CONTRACT
    (property_id, tenant_id, agent_id, start_date, end_date,
     monthly_rent, deposit_amount, commission_rate)
VALUES
    (701, 601, NULL, '2027-01-01', '2027-01-01',
     10000000.00, 20000000.00, 0.00);

-- T02 | Gia thue phai > 0
-- Mong doi: ERROR 3819 - Check constraint 'chk_contract_rent' is violated.
INSERT INTO LEASE_CONTRACT
    (property_id, tenant_id, agent_id, start_date, end_date,
     monthly_rent, deposit_amount, commission_rate)
VALUES
    (701, 601, NULL, '2027-01-01', '2028-01-01',
     0.00, 20000000.00, 0.00);

-- T03 | Trang thai hop dong chi nhan 4 gia tri hop le
-- Mong doi: ERROR 3819 - Check constraint 'chk_contract_status' is violated.
INSERT INTO LEASE_CONTRACT
    (property_id, tenant_id, agent_id, start_date, end_date,
     monthly_rent, deposit_amount, commission_rate, contract_status)
VALUES
    (701, 601, NULL, '2027-01-01', '2028-01-01',
     10000000.00, 20000000.00, 0.00, 'Pending');

-- T04 | BR2 (mot phan) | Trang thai bat dong san chi nhan 3 gia tri
-- Mong doi: ERROR 3819 - Check constraint 'chk_property_state' is violated.
UPDATE PROPERTY
SET current_state = 'Sold'
WHERE property_id = 701;

-- T05 | Gia thue bat dong san phai > 0
-- Mong doi: ERROR 3819 - Check constraint 'chk_property_price' is violated.
INSERT INTO PROPERTY (landlord_id, title, address, current_state, rental_price)
VALUES (251, 'Nha kiem thu', '1 Duong Kiem Thu, Quan 1, TP.HCM', 'Available', 0.00);

-- T06 | BR3 | So tien trong so cai phai > 0
-- Mong doi: ERROR 3819 - Check constraint 'chk_ledger_amount' is violated.
INSERT INTO FINANCIAL_LEDGER
    (property_id, payer_id, payee_id, related_contract_id, related_request_id,
     transaction_type, category, amount)
VALUES
    (1, 601, 380, NULL, NULL, 'INCOME', 'Deposit', 0.00);

-- T07a | Hang muc dong tien khong hop le
-- Mong doi: ERROR 3819 - Check constraint 'chk_ledger_category' is violated.
INSERT INTO FINANCIAL_LEDGER
    (property_id, payer_id, payee_id, related_contract_id, related_request_id,
     transaction_type, category, amount)
VALUES
    (1, 601, 380, NULL, NULL, 'INCOME', 'Bonus', 1000.00);

-- T07b | Loai giao dich khong hop le (chi INCOME / EXPENSE)
-- Mong doi: ERROR 3819 - Check constraint 'chk_ledger_type' is violated.
INSERT INTO FINANCIAL_LEDGER
    (property_id, payer_id, payee_id, related_contract_id, related_request_id,
     transaction_type, category, amount)
VALUES
    (1, 601, 380, NULL, NULL, 'REFUND', 'Deposit', 1000.00);

-- T08 | Email nguoi dung phai duy nhat (user 1 da dung user0001@...)
-- Mong doi: ERROR 1062 - Duplicate entry ... for key 'USERS.email'.
UPDATE USERS
SET email = 'user0001@realestate-ledger.vn'
WHERE user_id = 2;

-- T09 | So CCCD phai duy nhat (ATL user 101 da dung 079010000101)
-- Mong doi: ERROR 1062 - Duplicate entry '079010000101' for key 'ATL.identity_card_number'.
UPDATE ATL
SET identity_card_number = '079010000101'
WHERE user_id = 102;

-- T10 | Cot NOT NULL khong nhan NULL
-- Mong doi: ERROR 1048 - Column 'full_name' cannot be null.
INSERT INTO USERS (full_name, email, password_hash, phone_number)
VALUES (NULL, 'kiemthu@realestate-ledger.vn', 'hash', '0900000000');

-- T11a | Ma nhan vien phai bat dau bang 'EMP-'
-- Mong doi: ERROR 3819 - Check constraint 'chk_ap_emp_code' is violated.
UPDATE AP
SET employee_code = 'ABC-0001'
WHERE user_id = 1;

-- T11b | Cap do truy cap chi tu 1 den 3
-- Mong doi: ERROR 3819 - Check constraint 'chk_ap_access_level' is violated.
UPDATE AP
SET access_level = 5
WHERE user_id = 1;

-- T12 | Ty le hoa hong mac dinh cua moi gioi trong 0..100
-- Mong doi: ERROR 3819 - Check constraint 'chk_agent_comm_rate' is violated.
UPDATE AGENT
SET default_commission_rate = 150.00
WHERE agent_id = 101;

-- T13a | Trang thai phieu bao tri khong hop le
-- Mong doi: ERROR 3819 - Check constraint 'chk_maint_status' is violated.
UPDATE MAINTENANCE_REQUEST
SET request_status = 'Done'
WHERE request_id = 1;

-- T13b | Chi phi du toan khong am
-- Mong doi: ERROR 3819 - Check constraint 'chk_maint_est_cost' is violated.
UPDATE MAINTENANCE_REQUEST
SET estimated_cost = -1.00
WHERE request_id = 1;


-- -------------------------------------------------------------------------
-- NHOM B. TOAN VEN THAM CHIEU (FOREIGN KEY)
-- -------------------------------------------------------------------------

-- T14 | BR1 (quyen so huu) | Chi LANDLORD moi so huu duoc bat dong san
-- User 120 la Agent, khong phai Landlord.
-- Mong doi: ERROR 1452 - Cannot add or update a child row ... 'fk_property_landlord'.
INSERT INTO PROPERTY (landlord_id, title, address, current_state, rental_price)
VALUES (120, 'Nha cua mot moi gioi', '2 Duong Kiem Thu, Quan 3, TP.HCM', 'Available', 9000000.00);

-- T15 | Hop dong phai gan voi mot TENANT hop le (user 120 la Agent)
-- Mong doi: ERROR 1452 ... 'fk_contract_tenant'.
INSERT INTO LEASE_CONTRACT
    (property_id, tenant_id, agent_id, start_date, end_date,
     monthly_rent, deposit_amount, commission_rate)
VALUES
    (701, 120, NULL, '2027-01-01', '2028-01-01', 10000000.00, 20000000.00, 0.00);

-- T16 | Nhat ky trang thai chi do PROPERTY_MANAGER ghi (user 1 la Admin)
-- Mong doi: ERROR 1452 ... 'fk_history_manager'. (Tach quyen Admin / Manager)
INSERT INTO PROPERTY_STATE_HISTORY
    (property_id, changed_by, old_state, new_state, change_reason)
VALUES
    (701, 1, 'Available', 'Leased', 'Kiem thu rang buoc phan quyen');

-- T17 | Khong xoa duoc Landlord dang so huu bat dong san (ON DELETE RESTRICT)
-- Landlord 251 so huu cac can 380, 760, 1140.
-- Mong doi: ERROR 1451 - Cannot delete or update a parent row ... 'fk_property_landlord'.
DELETE FROM LANDLORD
WHERE landlord_id = 251;

-- T18 | Khong xoa duoc bat dong san da co hop dong / so cai (RESTRICT)
-- Mong doi: ERROR 1451 ... (fk_contract_property hoac fk_ledger_property).
DELETE FROM PROPERTY
WHERE property_id = 1;


-- -------------------------------------------------------------------------
-- NHOM C. TRIGGER NGHIEP VU (BR2, BR3, BR4, BR5)
-- -------------------------------------------------------------------------

-- T19 | BR3 | Cam UPDATE so cai
-- Mong doi: ERROR 1644 (45000): VI PHAM BR3: ... nghiem cam thao tac UPDATE!
UPDATE FINANCIAL_LEDGER
SET amount = amount + 1
WHERE ledger_id = 1;

-- T20 | BR3 | Cam DELETE so cai
-- Mong doi: ERROR 1644 (45000): VI PHAM BR3: ... nghiem cam thao tac DELETE!
DELETE FROM FINANCIAL_LEDGER
WHERE ledger_id = 1;

-- T21 | BR2 | Khong kich hoat hop dong cho can nha dang Leased
-- Property 1 dang 'Leased'. Hop dong moi tao o trang thai Draft (mac dinh).
-- Mong doi: UPDATE bi tu choi voi ERROR 1644: VI PHAM BR2 ... khong o trang thai Available.
START TRANSACTION;
INSERT INTO LEASE_CONTRACT
    (property_id, tenant_id, agent_id, start_date, end_date,
     monthly_rent, deposit_amount, commission_rate)
VALUES
    (1, 602, NULL, '2027-01-01', '2028-01-01', 10000000.00, 20000000.00, 0.00);
SET @contract_id = LAST_INSERT_ID();
UPDATE LEASE_CONTRACT
SET contract_status = 'Active'
WHERE contract_id = @contract_id;
-- (Loi xay ra o cau UPDATE tren.) Hoan tac de khong de lai hop dong thua:
ROLLBACK;

-- T22 | BR4 | Khong co hai hop dong Active tren cung mot bat dong san
-- Cach dung: INSERT truc tiep mot hop dong Active (INSERT khong kich trigger),
-- sau do thu kich hoat them mot hop dong khac tren cung can 701 (dang Available).
-- Mong doi: ERROR 1644: VI PHAM BR4 ... dang co hop dong thue Active khac.
START TRANSACTION;
INSERT INTO LEASE_CONTRACT
    (property_id, tenant_id, agent_id, start_date, end_date,
     monthly_rent, deposit_amount, commission_rate, contract_status)
VALUES
    (701, 603, NULL, '2027-01-01', '2028-01-01', 10000000.00, 20000000.00, 0.00, 'Active');
INSERT INTO LEASE_CONTRACT
    (property_id, tenant_id, agent_id, start_date, end_date,
     monthly_rent, deposit_amount, commission_rate)
VALUES
    (701, 604, NULL, '2027-01-01', '2028-01-01', 10000000.00, 20000000.00, 0.00);
SET @contract_id = LAST_INSERT_ID();
UPDATE LEASE_CONTRACT
SET contract_status = 'Active'
WHERE contract_id = @contract_id;
ROLLBACK;

-- T23 | BR2 + BR5 + ACID | Luong thanh cong: kich hoat hop dong co moi gioi
-- Can 702 dang Available (chu nha = user 573). Hop dong: thue 10.000.000, coc 20.000.000,
-- hoa hong 5% => hoa hong = 500.000.
-- Mong doi sau UPDATE: PROPERTY 702 = 'Leased'; so cai them dung 2 dong:
--   INCOME  Deposit          20000000.00  payer 601 -> payee 573
--   EXPENSE Agent_Commission   500000.00  payer 573 -> payee 102
-- Sau ROLLBACK: can 702 tro lai 'Available' va so cai tro lai 10000 dong.
START TRANSACTION;
SELECT COUNT(*) AS so_dong_so_cai_truoc FROM FINANCIAL_LEDGER;
SELECT current_state AS trang_thai_truoc FROM PROPERTY WHERE property_id = 702;
INSERT INTO LEASE_CONTRACT
    (property_id, tenant_id, agent_id, start_date, end_date,
     monthly_rent, deposit_amount, commission_rate)
VALUES
    (702, 601, 102, '2027-01-01', '2028-01-01', 10000000.00, 20000000.00, 5.00);
SET @contract_id = LAST_INSERT_ID();
UPDATE LEASE_CONTRACT
SET contract_status = 'Active'
WHERE contract_id = @contract_id;
SELECT current_state AS trang_thai_sau FROM PROPERTY WHERE property_id = 702;
SELECT ledger_id, transaction_type, category, amount, payer_id, payee_id
FROM FINANCIAL_LEDGER
WHERE related_contract_id = @contract_id
ORDER BY ledger_id;
ROLLBACK;
-- Kiem tra tinh nguyen tu (Atomicity): moi thu da quay ve nhu cu
SELECT current_state AS trang_thai_sau_rollback FROM PROPERTY WHERE property_id = 702;
SELECT COUNT(*) AS so_dong_so_cai_sau_rollback FROM FINANCIAL_LEDGER;

-- T24 | BR5 | Hop dong ky truc tiep (khong moi gioi) chi ghi coc, khong ghi hoa hong
-- Mong doi: dung 1 dong so cai (Deposit); khong co dong Agent_Commission.
START TRANSACTION;
INSERT INTO LEASE_CONTRACT
    (property_id, tenant_id, agent_id, start_date, end_date,
     monthly_rent, deposit_amount, commission_rate)
VALUES
    (703, 605, NULL, '2027-01-01', '2028-01-01', 12000000.00, 24000000.00, 0.00);
SET @contract_id = LAST_INSERT_ID();
UPDATE LEASE_CONTRACT
SET contract_status = 'Active'
WHERE contract_id = @contract_id;
SELECT category, transaction_type, amount
FROM FINANCIAL_LEDGER
WHERE related_contract_id = @contract_id;
ROLLBACK;


-- -------------------------------------------------------------------------
-- NHOM D. DIEM YEU DA BIET (KHONG PHAI LOI CODE, CAN BIET DE TRA LOI VAN DAP)
-- Cac test duoi day CHO THAY he thong KHONG chan duoc -- hay trinh bay trung thuc
-- trong muc "Han che" va de xuat cach khac phuc (xem OPTIONAL_hardening.sql).
-- -------------------------------------------------------------------------

-- G1 | Trigger BR2 chi chay khi KICH HOAT HOP DONG, khong chay khi UPDATE thang bang PROPERTY
-- Can 1100 dang 'Under Maintenance'. UPDATE thang len 'Leased' (vi pham BR2) van THANH CONG.
START TRANSACTION;
UPDATE PROPERTY SET current_state = 'Leased' WHERE property_id = 1100;
SELECT property_id, current_state FROM PROPERTY WHERE property_id = 1100;
ROLLBACK;

-- G2 | BR4 chi duoc kiem tra khi UPDATE sang Active; INSERT thang van tao duoc 2 hop dong Active
START TRANSACTION;
INSERT INTO LEASE_CONTRACT
    (property_id, tenant_id, agent_id, start_date, end_date,
     monthly_rent, deposit_amount, commission_rate, contract_status)
VALUES
    (704, 606, NULL, '2027-01-01', '2028-01-01', 10000000.00, 20000000.00, 0.00, 'Active'),
    (704, 607, NULL, '2027-01-01', '2028-01-01', 10000000.00, 20000000.00, 0.00, 'Active');
SELECT contract_id, property_id, contract_status
FROM LEASE_CONTRACT
WHERE property_id = 704 AND contract_status = 'Active';
ROLLBACK;

-- G3 | Rang buoc "roi rac" AP/ATL chi duoc mo ta tren tai lieu, DDL chua chan
-- User 5 la Admin (thuoc AP). Chen them vao ATL van THANH CONG.
START TRANSACTION;
INSERT INTO ATL (user_id, identity_card_number, address)
VALUES (5, '0790TEST00005', 'Dia chi kiem thu');
SELECT a.user_id AS user_vua_o_AP_vua_o_ATL
FROM AP a
JOIN ATL t ON t.user_id = a.user_id;
ROLLBACK;

-- G4 | ON DELETE SET NULL cho phep xoa hop dong va lam NULL cot lien ket o so cai
-- (hanh dong FK khong kich hoat trigger) -> dong so cai bi "sua" ngam.
START TRANSACTION;
SELECT COUNT(*) AS so_cai_gan_hop_dong_1_truoc
FROM FINANCIAL_LEDGER WHERE related_contract_id = 1;
DELETE FROM LEASE_CONTRACT WHERE contract_id = 1;
SELECT COUNT(*) AS so_cai_gan_hop_dong_1_sau
FROM FINANCIAL_LEDGER WHERE related_contract_id = 1;
ROLLBACK;

-- G5 | TRUNCATE khong kich hoat trigger DELETE. Chi chan duoc bang QUYEN (muc 5.2).
-- (KHONG chay lenh duoi day tren du lieu that; chi de giai thich)
-- TRUNCATE TABLE FINANCIAL_LEDGER;

-- G6 | Kiem tra nhat quan du lieu mau voi BR5
-- Hop dong 'Draft' khong nen co dong tien trong so cai, nhung du lieu mau nap hang loat
-- (INSERT ... SELECT khong di qua trigger) nen co.
-- Mong doi theo cong thuc nap: 200 hop dong Draft deu co dong coc.
SELECT COUNT(DISTINCT lc.contract_id) AS hop_dong_draft_co_dong_tien
FROM LEASE_CONTRACT lc
JOIN FINANCIAL_LEDGER fl ON fl.related_contract_id = lc.contract_id
WHERE lc.contract_status = 'Draft';
