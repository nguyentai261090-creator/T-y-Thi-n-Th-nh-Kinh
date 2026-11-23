-- =========================================================================
-- DE TAI: #10 Real Estate Property & Rental Ledger
-- NHOM THUC HIEN: Tay Thien Thinh Kinh
-- MUC 5.2: ROLE-BASED ACCESS CONTROL (RBAC) - ROLE, GRANT, REVOKE, VIEW LOC HANG
-- =========================================================================
-- YEU CAU: MySQL 8.0+ (co ROLE). Chay bang tai khoan root (DBA).
-- CHAY SAU 6 file: DDL, INDEX, VIEWS, TRIGGERS, DATA_INSERTION (DATA_AGGREGATION tuy y).
-- NGUYEN TAC: quyen toi thieu (least privilege) + tach nhiem vu (separation of duties).
--   1. Quyen DDL chi cap cho role_admin.
--   2. KHONG role nao co UPDATE / DELETE tren FINANCIAL_LEDGER (BR3).
--   3. Chi role_property_manager duoc doi trang thai; chi chu nha moi thay nha cua minh.
--   4. MySQL khong co row-level security -> loc hang bang VIEW + ham fn_session_user_id()
--      (quy uoc ten tai khoan DB: <vai_tro>_<UserID>, vi du tenant_601).
-- TRANG THAI: chua duoc chay thu tren MySQL trong moi truong soan thao.
-- =========================================================================

USE real_estate_ledger;

-- -------------------------------------------------------------------------
-- BUOC 0. HAM LAY UserID TU TEN TAI KHOAN DANG NHAP (dung cho VIEW loc hang)
-- USER() tra ve 'tenant_601@localhost' -> ham tra ve 601; tai khoan khac -> 0
-- -------------------------------------------------------------------------
DROP FUNCTION IF EXISTS fn_session_user_id;

DELIMITER //
CREATE FUNCTION fn_session_user_id()
RETURNS INT
NO SQL
BEGIN
    RETURN IF(
        USER() REGEXP '^[a-z]+_[0-9]+@',
        CAST(SUBSTRING_INDEX(SUBSTRING_INDEX(USER(), '@', 1), '_', -1) AS UNSIGNED),
        0
    );
END //
DELIMITER ;

-- -------------------------------------------------------------------------
-- BUOC 1. VIEW LOC HANG THEO NGUOI DANG NHAP (tac dung bao ve cua VIEW - DB_12)
-- -------------------------------------------------------------------------

-- Moi gioi: chi thay hop dong cua chinh minh; INSERT chi duoc phep cho chinh minh
CREATE OR REPLACE VIEW vw_agent_contracts AS
SELECT
    contract_id, property_id, tenant_id, agent_id,
    start_date, end_date, monthly_rent, deposit_amount,
    commission_rate, contract_status
FROM LEASE_CONTRACT
WHERE agent_id = fn_session_user_id()
WITH CHECK OPTION;

-- Khach thue: hop dong, lich su tra tien, phieu bao tri cua chinh minh
CREATE OR REPLACE VIEW vw_tenant_my_contracts AS
SELECT
    contract_id, property_id, start_date, end_date,
    monthly_rent, deposit_amount, contract_status
FROM LEASE_CONTRACT
WHERE tenant_id = fn_session_user_id();

CREATE OR REPLACE VIEW vw_tenant_my_payments AS
SELECT
    ledger_id, property_id, related_contract_id,
    category, amount, created_at
FROM FINANCIAL_LEDGER
WHERE payer_id = fn_session_user_id()
  AND transaction_type = 'INCOME';

CREATE OR REPLACE VIEW vw_tenant_maintenance AS
SELECT
    request_id, property_id, tenant_id, description,
    request_status, created_at
FROM MAINTENANCE_REQUEST
WHERE tenant_id = fn_session_user_id()
WITH CHECK OPTION;

-- Chu nha: bat dong san, bao cao thu/chi, chi tiet so cai cua nha minh
CREATE OR REPLACE VIEW vw_landlord_my_properties AS
SELECT
    property_id, title, address, current_state, rental_price, created_at
FROM PROPERTY
WHERE landlord_id = fn_session_user_id();

CREATE OR REPLACE VIEW vw_landlord_my_financials AS
SELECT *
FROM vw_property_financial_summary
WHERE landlord_id = fn_session_user_id();

CREATE OR REPLACE VIEW vw_landlord_my_ledger AS
SELECT
    fl.ledger_id, fl.property_id, fl.transaction_type,
    fl.category, fl.amount, fl.created_at
FROM FINANCIAL_LEDGER fl
JOIN PROPERTY p ON p.property_id = fl.property_id
WHERE p.landlord_id = fn_session_user_id();

-- -------------------------------------------------------------------------
-- BUOC 2. TAO 5 ROLE
-- -------------------------------------------------------------------------
CREATE ROLE IF NOT EXISTS
    'role_admin',
    'role_property_manager',
    'role_agent',
    'role_tenant',
    'role_landlord';

-- -------------------------------------------------------------------------
-- BUOC 3. CAP QUYEN (GRANT) - THEO QUYEN TOI THIEU
-- -------------------------------------------------------------------------

-- 3.1 ADMIN: DDL + quan tri tai khoan nguoi dung + DOC nhat ky va so cai
GRANT CREATE, ALTER, DROP, INDEX, REFERENCES, TRIGGER,
      CREATE VIEW, SHOW VIEW, CREATE ROUTINE, ALTER ROUTINE, EXECUTE
    ON real_estate_ledger.* TO 'role_admin';

GRANT SELECT, INSERT, UPDATE, DELETE ON real_estate_ledger.USERS            TO 'role_admin';
GRANT SELECT, INSERT, UPDATE, DELETE ON real_estate_ledger.AP               TO 'role_admin';
GRANT SELECT, INSERT, UPDATE, DELETE ON real_estate_ledger.ADMIN            TO 'role_admin';
GRANT SELECT, INSERT, UPDATE, DELETE ON real_estate_ledger.PROPERTY_MANAGER TO 'role_admin';
GRANT SELECT, INSERT, UPDATE, DELETE ON real_estate_ledger.ATL              TO 'role_admin';
GRANT SELECT, INSERT, UPDATE, DELETE ON real_estate_ledger.AGENT            TO 'role_admin';
GRANT SELECT, INSERT, UPDATE, DELETE ON real_estate_ledger.TENANT           TO 'role_admin';
GRANT SELECT, INSERT, UPDATE, DELETE ON real_estate_ledger.LANDLORD         TO 'role_admin';

-- Audit trail: chi DOC (khong sua duoc so cai, khong doi trang thai tai san)
GRANT SELECT ON real_estate_ledger.PROPERTY               TO 'role_admin';
GRANT SELECT ON real_estate_ledger.PROPERTY_STATE_HISTORY TO 'role_admin';
GRANT SELECT ON real_estate_ledger.LEASE_CONTRACT         TO 'role_admin';
GRANT SELECT ON real_estate_ledger.MAINTENANCE_REQUEST    TO 'role_admin';
GRANT SELECT ON real_estate_ledger.FINANCIAL_LEDGER       TO 'role_admin';

-- Cap phat tai khoan / phan quyen (quyen toan cuc cua MySQL)
GRANT CREATE USER, CREATE ROLE, DROP ROLE, ROLE_ADMIN ON *.* TO 'role_admin';

-- 3.2 PROPERTY MANAGER: doi trang thai, duyet hop dong, quyet toan bao tri
GRANT SELECT ON real_estate_ledger.PROPERTY               TO 'role_property_manager';
GRANT SELECT ON real_estate_ledger.LEASE_CONTRACT         TO 'role_property_manager';
GRANT SELECT ON real_estate_ledger.MAINTENANCE_REQUEST    TO 'role_property_manager';
GRANT SELECT ON real_estate_ledger.PROPERTY_STATE_HISTORY TO 'role_property_manager';
GRANT SELECT ON real_estate_ledger.FINANCIAL_LEDGER       TO 'role_property_manager';
-- Quyen o MUC COT: chi duoc sua dung cot nghiep vu cua minh
GRANT UPDATE (current_state) ON real_estate_ledger.PROPERTY TO 'role_property_manager';
GRANT UPDATE (contract_status) ON real_estate_ledger.LEASE_CONTRACT TO 'role_property_manager';
GRANT UPDATE (assigned_manager_id, estimated_cost, actual_cost, request_status, resolved_at)
    ON real_estate_ledger.MAINTENANCE_REQUEST TO 'role_property_manager';
-- Ghi nhat ky va ghi chi phi bao tri vao so cai (chi INSERT, khong UPDATE/DELETE)
GRANT INSERT ON real_estate_ledger.PROPERTY_STATE_HISTORY TO 'role_property_manager';
GRANT INSERT ON real_estate_ledger.FINANCIAL_LEDGER       TO 'role_property_manager';

-- 3.3 AGENT: xem nha trong, soan hop dong NHAP cua chinh minh
GRANT SELECT ON real_estate_ledger.vw_available_properties TO 'role_agent';
GRANT SELECT ON real_estate_ledger.vw_agent_contracts      TO 'role_agent';
-- INSERT o muc cot: KHONG co contract_status -> luon nhan mac dinh 'Draft'
GRANT INSERT (property_id, tenant_id, agent_id, start_date, end_date,
              monthly_rent, deposit_amount, commission_rate)
    ON real_estate_ledger.vw_agent_contracts TO 'role_agent';

-- 3.4 TENANT: xem du lieu cua minh, gui phieu bao tri (Pending)
GRANT SELECT ON real_estate_ledger.vw_tenant_my_contracts TO 'role_tenant';
GRANT SELECT ON real_estate_ledger.vw_tenant_my_payments  TO 'role_tenant';
GRANT SELECT ON real_estate_ledger.vw_tenant_maintenance  TO 'role_tenant';
GRANT INSERT (property_id, tenant_id, description)
    ON real_estate_ledger.vw_tenant_maintenance TO 'role_tenant';

-- 3.5 LANDLORD: chi doc du lieu cua nha minh
GRANT SELECT ON real_estate_ledger.vw_landlord_my_properties TO 'role_landlord';
GRANT SELECT ON real_estate_ledger.vw_landlord_my_financials TO 'role_landlord';
GRANT SELECT ON real_estate_ledger.vw_landlord_my_ledger     TO 'role_landlord';

-- Cac role dung view co ham can quyen EXECUTE de chac chan
GRANT EXECUTE ON FUNCTION real_estate_ledger.fn_session_user_id
    TO 'role_agent', 'role_tenant', 'role_landlord';

-- -------------------------------------------------------------------------
-- BUOC 4. TAO TAI KHOAN MINH HOA VA GAN ROLE
-- Thay <DAT_MAT_KHAU> bang mat khau rieng truoc khi chay. KHONG commit mat khau that len GitHub.
-- -------------------------------------------------------------------------
CREATE USER IF NOT EXISTS 'admin_1'@'localhost'    IDENTIFIED BY '<DAT_MAT_KHAU>';
CREATE USER IF NOT EXISTS 'manager_16'@'localhost' IDENTIFIED BY '<DAT_MAT_KHAU>';
CREATE USER IF NOT EXISTS 'agent_102'@'localhost'  IDENTIFIED BY '<DAT_MAT_KHAU>';
CREATE USER IF NOT EXISTS 'tenant_601'@'localhost' IDENTIFIED BY '<DAT_MAT_KHAU>';
CREATE USER IF NOT EXISTS 'landlord_251'@'localhost' IDENTIFIED BY '<DAT_MAT_KHAU>';

GRANT 'role_admin'            TO 'admin_1'@'localhost';
GRANT 'role_property_manager' TO 'manager_16'@'localhost';
GRANT 'role_agent'            TO 'agent_102'@'localhost';
GRANT 'role_tenant'           TO 'tenant_601'@'localhost';
GRANT 'role_landlord'         TO 'landlord_251'@'localhost';

SET DEFAULT ROLE 'role_admin'            TO 'admin_1'@'localhost';
SET DEFAULT ROLE 'role_property_manager' TO 'manager_16'@'localhost';
SET DEFAULT ROLE 'role_agent'            TO 'agent_102'@'localhost';
SET DEFAULT ROLE 'role_tenant'           TO 'tenant_601'@'localhost';
SET DEFAULT ROLE 'role_landlord'         TO 'landlord_251'@'localhost';

-- -------------------------------------------------------------------------
-- BUOC 5. KIEM TRA QUYEN DA CAP (chup man hinh dua vao bao cao)
-- -------------------------------------------------------------------------
SHOW GRANTS FOR 'role_admin';
SHOW GRANTS FOR 'role_property_manager';
SHOW GRANTS FOR 'role_agent';
SHOW GRANTS FOR 'role_tenant';
SHOW GRANTS FOR 'role_landlord';
SHOW GRANTS FOR 'agent_102'@'localhost' USING 'role_agent';

-- -------------------------------------------------------------------------
-- BUOC 6. THU HOI QUYEN (REVOKE) - CAC KICH BAN THUC TE
-- -------------------------------------------------------------------------

-- 6.1 Quan ly nghi viec: go role khoi tai khoan (tai khoan van ton tai, mat quyen)
REVOKE 'role_property_manager' FROM 'manager_16'@'localhost';
-- ... va cap lai khi quay lai lam viec:
GRANT 'role_property_manager' TO 'manager_16'@'localhost';
SET DEFAULT ROLE 'role_property_manager' TO 'manager_16'@'localhost';

-- 6.2 Thu hoi mot quyen cu the khoi role: quan ly khong con tu ghi so cai
REVOKE INSERT ON real_estate_ledger.FINANCIAL_LEDGER FROM 'role_property_manager';
-- Kiem tra: dang nhap lai manager_16 roi thu INSERT vao FINANCIAL_LEDGER -> ERROR 1142
-- Cap lai:
GRANT INSERT ON real_estate_ledger.FINANCIAL_LEDGER TO 'role_property_manager';

-- 6.3 Thu hoi quyen DDL cua Admin tren mot bang (vi du khoa bang so cai khoi DROP)
-- Luu y: quyen DROP duoc cap o muc co so du lieu (db.*), nen khong the thu hoi rieng
-- tren mot bang. Muon chan DROP FINANCIAL_LEDGER phai cap DROP tung bang thay vi db.*.
-- (Day la hanh vi cua MySQL, xem ghi chu muc 5.2 bao cao.)
