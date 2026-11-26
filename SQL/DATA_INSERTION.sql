-- =========================================================================
-- ĐỀ TÀI: #10 Real Estate Property & Rental Ledger
-- NHÓM THỰC HIỆN: Tây Thiên Thỉnh Kinh
-- MỤC 4.2: DATA INSERTION (BULK DML & MOCK DATA - 23.900 BẢN GHI)
-- =========================================================================

USE real_estate_ledger;

-- 1. Dọn dẹp sạch dữ liệu cũ an toàn để tránh lỗi trùng khóa (Error 1062)
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE FINANCIAL_LEDGER;
TRUNCATE TABLE MAINTENANCE_REQUEST;
TRUNCATE TABLE LEASE_CONTRACT;
TRUNCATE TABLE PROPERTY_STATE_HISTORY;
TRUNCATE TABLE PROPERTY;
TRUNCATE TABLE LANDLORD;
TRUNCATE TABLE TENANT;
TRUNCATE TABLE AGENT;
TRUNCATE TABLE ATL;
TRUNCATE TABLE PROPERTY_MANAGER;
TRUNCATE TABLE ADMIN;
TRUNCATE TABLE AP;
TRUNCATE TABLE USERS;
SET FOREIGN_KEY_CHECKS = 1;

-- 2. Tạo bảng chuỗi số tạm (1 -> 10.000) 
DROP TEMPORARY TABLE IF EXISTS tmp_seq;
CREATE TEMPORARY TABLE tmp_seq (n INT PRIMARY KEY);

INSERT INTO tmp_seq (n)
SELECT (a.d * 1000 + b.d * 100 + c.d * 10 + d.d) + 1 AS n
FROM (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a
CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b
CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c
CROSS JOIN (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d;

START TRANSACTION;

-- -------------------------------------------------------------------------
-- BƯỚC 1: NẠP 1.500 NGƯỜI DÙNG (USERS) & PHÂN CẤP KẾ THỪA (OPTION 8A)
-- -------------------------------------------------------------------------
INSERT INTO USERS (user_id, full_name, email, password_hash, phone_number, created_at)
SELECT 
    n AS user_id,
    CONCAT(
        ELT(1 + (n % 10), 'Nguyễn', 'Trần', 'Lê', 'Phạm', 'Hoàng', 'Huỳnh', 'Phan', 'Vũ', 'Đặng', 'Bùi'), ' ',
        ELT(1 + ((n * 3) % 8), 'Văn', 'Thị', 'Minh', 'Hoàng', 'Anh', 'Thanh', 'Quốc', 'Ngọc'), ' ',
        ELT(1 + ((n * 7) % 12), 'An', 'Bình', 'Cường', 'Dũng', 'Giang', 'Hương', 'Khánh', 'Linh', 'Nam', 'Phúc', 'Tài', 'Nguyên')
    ) AS full_name,
    CONCAT('user', LPAD(n, 4, '0'), '@realestate-ledger.vn') AS email,
    SHA2(CONCAT('Pass@', n, '2026'), 256) AS password_hash,
    CONCAT('09', LPAD(10000000 + n * 53, 8, '0')) AS phone_number,
    DATE_SUB('2026-01-01 08:00:00', INTERVAL (1500 - n) HOUR) AS created_at
FROM tmp_seq
WHERE n <= 1500;

-- 1.1 Nhánh AP (100 nhân sự nội bộ: user_id 1 -> 100)
INSERT INTO AP (user_id, employee_code, access_level)
SELECT 
    n,
    CONCAT('EMP-', LPAD(n, 4, '0')),
    IF(n <= 15, 3, 2)
FROM tmp_seq
WHERE n <= 100;

-- 1.2 ADMIN (15 quản trị viên: 1 -> 15) & PROPERTY_MANAGER (85 quản lý: 16 -> 100) [Rời rạc]
INSERT INTO ADMIN (admin_id, system_config_rights)
SELECT n, 'FULL_SYSTEM_AUDIT_AND_DDL'
FROM tmp_seq
WHERE n <= 15;

INSERT INTO PROPERTY_MANAGER (manager_id, assigned_zone)
SELECT 
    n,
    CONCAT('Khu vực ', ELT(1 + (n % 6), 'Quận 1', 'Quận 3', 'Quận 7', 'TP. Thủ Đức', 'Quận Bình Thạnh', 'Quận Phú Nhuận'), ' - TP.HCM')
FROM tmp_seq
WHERE n BETWEEN 16 AND 100;

-- 1.3 Nhánh ATL (1.400 đối tác & khách hàng: user_id 101 -> 1500)
INSERT INTO ATL (user_id, identity_card_number, address)
SELECT 
    n,
    CONCAT('0790', LPAD(10000000 + n, 8, '0')),
    CONCAT(n, ' Đường Nguyễn Văn Linh, ', ELT(1 + (n % 6), 'Quận 1', 'Quận 3', 'Quận 7', 'TP. Thủ Đức', 'Quận Bình Thạnh', 'Quận Phú Nhuận'), ', TP.HCM')
FROM tmp_seq
WHERE n BETWEEN 101 AND 1500;

-- 1.4 Subclass chồng lấn từ ATL: AGENT (200), LANDLORD (400), TENANT (900)
INSERT INTO AGENT (agent_id, broker_license, default_commission_rate)
SELECT 
    n,
    CONCAT('HCM-MG-', 2020 + (n % 7), '-', LPAD(n, 4, '0')),
    ROUND(3.00 + (n % 6) * 0.50, 2)
FROM tmp_seq
WHERE n BETWEEN 101 AND 300;

INSERT INTO LANDLORD (landlord_id, bank_account_number, bank_name, tax_code)
SELECT 
    n,
    CONCAT('1903', LPAD(500000000 + n * 73, 10, '0')),
    ELT(1 + (n % 5), 'Vietcombank', 'Techcombank', 'ACB', 'BIDV', 'MB Bank'),
    CONCAT('8', LPAD(100000000 + n * 31, 9, '0'))
FROM tmp_seq
WHERE n BETWEEN 251 AND 650;

INSERT INTO TENANT (tenant_id, emergency_contact)
SELECT 
    n,
    CONCAT('098', LPAD(1000000 + n * 47, 7, '0'))
FROM tmp_seq
WHERE n BETWEEN 601 AND 1500;

-- -------------------------------------------------------------------------
-- BƯỚC 2: NẠP 1.200 BẤT ĐỘNG SẢN THỰC TẾ TẠI TP.HCM (PROPERTY)
-- -------------------------------------------------------------------------
INSERT INTO PROPERTY (property_id, landlord_id, title, address, current_state, rental_price, created_at)
SELECT 
    n AS property_id,
    251 + (n % 380) AS landlord_id,
    CONCAT(
        ELT(1 + (n % 4), 'Căn hộ cao cấp', 'Nhà phố nguyên căn', 'Shophouse thương mại', 'Căn hộ Studio'), ' ',
        ELT(1 + (n % 6), 'Quận 1', 'Quận 3', 'Quận 7', 'TP. Thủ Đức', 'Quận Bình Thạnh', 'Quận Phú Nhuận'),
        ' - Mã căn P', LPAD(n, 4, '0')
    ) AS title,
    CONCAT('Số ', n, ' Đường Lê Lợi, ', ELT(1 + (n % 6), 'Quận 1', 'Quận 3', 'Quận 7', 'TP. Thủ Đức', 'Quận Bình Thạnh', 'Quận Phú Nhuận'), ', TP.HCM') AS address,
    CASE 
        WHEN n <= 500 THEN 'Leased'
        WHEN n <= 1050 THEN 'Available'
        ELSE 'Under Maintenance'
    END AS current_state,
    (8 + (n % 43)) * 1000000.00 AS rental_price,
    DATE_SUB('2026-03-01 09:00:00', INTERVAL (1200 - n) HOUR) AS created_at
FROM tmp_seq
WHERE n <= 1200;

-- -------------------------------------------------------------------------
-- BƯỚC 3: NẠP 3.600 NHẬT KÝ CHUYỂN TRẠNG THÁI (PROPERTY_STATE_HISTORY)
-- -------------------------------------------------------------------------
INSERT INTO PROPERTY_STATE_HISTORY (history_id, property_id, changed_by, old_state, new_state, change_reason, changed_at)
SELECT 
    n AS history_id,
    1 + (n % 1200) AS property_id,
    16 + (n % 85) AS changed_by,
    ELT(1 + (n % 3), 'Available', 'Leased', 'Under Maintenance') AS old_state,
    ELT(1 + (n % 3), 'Leased', 'Under Maintenance', 'Available') AS new_state,
    ELT(1 + (n % 3),
        'Kích hoạt hợp đồng cho thuê mới sau khi xác nhận tiền cọc',
        'Tạm khóa tài sản để bảo trì kỹ thuật định kỳ',
        'Nghiệm thu hoàn tất sửa chữa, mở niêm yết cho thuê lại'
    ) AS change_reason,
    DATE_SUB('2026-09-01 10:00:00', INTERVAL (3600 - n) HOUR) AS changed_at
FROM tmp_seq
WHERE n <= 3600;

-- -------------------------------------------------------------------------
-- BƯỚC 4: NẠP 2.000 HỢP ĐỒNG CHO THUÊ (LEASE_CONTRACT)
-- -------------------------------------------------------------------------
INSERT INTO LEASE_CONTRACT (
    contract_id, property_id, tenant_id, agent_id,
    start_date, end_date, monthly_rent, deposit_amount,
    commission_rate, contract_status, created_at
)
SELECT 
    s.n AS contract_id,
    CASE 
        WHEN s.n <= 500 THEN s.n
        WHEN s.n <= 1800 THEN 1 + (s.n % 1050)
        ELSE 501 + (s.n % 550)
    END AS property_id,
    601 + (s.n % 900) AS tenant_id,
    CASE WHEN s.n % 5 = 0 THEN NULL ELSE 101 + (s.n % 200) END AS agent_id,
    CASE 
        WHEN s.n <= 500 THEN DATE_ADD('2026-01-01', INTERVAL (s.n % 150) DAY)
        WHEN s.n <= 1800 THEN DATE_ADD('2024-01-01', INTERVAL (s.n % 300) DAY)
        ELSE DATE_ADD('2026-10-01', INTERVAL (s.n % 45) DAY)
    END AS start_date,
    CASE 
        WHEN s.n <= 500 THEN DATE_ADD(DATE_ADD('2026-01-01', INTERVAL (s.n % 150) DAY), INTERVAL 12 MONTH)
        WHEN s.n <= 1800 THEN DATE_ADD(DATE_ADD('2024-01-01', INTERVAL (s.n % 300) DAY), INTERVAL 12 MONTH)
        ELSE DATE_ADD(DATE_ADD('2026-10-01', INTERVAL (s.n % 45) DAY), INTERVAL 12 MONTH)
    END AS end_date,
    p.rental_price AS monthly_rent,
    p.rental_price * 2 AS deposit_amount,
    CASE WHEN s.n % 5 = 0 THEN 0.00 ELSE 5.00 END AS commission_rate,
    CASE 
        WHEN s.n <= 500 THEN 'Active'
        WHEN s.n <= 1500 THEN 'Expired'
        WHEN s.n <= 1800 THEN 'Terminated'
        ELSE 'Draft'
    END AS contract_status,
    DATE_SUB('2026-09-15 08:00:00', INTERVAL (2000 - s.n) HOUR) AS created_at
FROM tmp_seq s
JOIN PROPERTY p ON p.property_id = (
    CASE 
        WHEN s.n <= 500 THEN s.n
        WHEN s.n <= 1800 THEN 1 + (s.n % 1050)
        ELSE 501 + (s.n % 550)
    END
)
WHERE s.n <= 2000;

-- -------------------------------------------------------------------------
-- BƯỚC 5: NẠP 2.500 YÊU CẦU BẢO TRÌ (MAINTENANCE_REQUEST)
-- -------------------------------------------------------------------------
INSERT INTO MAINTENANCE_REQUEST (
    request_id, property_id, tenant_id, assigned_manager_id,
    description, estimated_cost, actual_cost, request_status,
    created_at, resolved_at
)
SELECT 
    n AS request_id,
    1 + (n % 1100) AS property_id,
    601 + (n % 900) AS tenant_id,
    CASE WHEN n BETWEEN 2151 AND 2400 THEN NULL ELSE 16 + (n % 85) END AS assigned_manager_id,
    ELT(1 + (n % 6),
        'Sửa chữa rò rỉ đường ống nước nhà vệ sinh',
        'Bảo dưỡng và nạp gas hệ thống điều hòa trung tâm',
        'Thay thế ổ khóa từ cửa chính bị lỗi cảm biến',
        'Xử lý thấm trần và sơn lại tường phòng khách',
        'Sửa chập mạch hệ thống đèn chiếu sáng ban công',
        'Thay mới máy bơm tăng áp nước sinh hoạt'
    ) AS description,
    (5 + (n % 45)) * 100000.00 AS estimated_cost,
    CASE WHEN n <= 1500 THEN (5 + (n % 45)) * 100000.00 + 150000.00 ELSE 0.00 END AS actual_cost,
    CASE 
        WHEN n <= 1500 THEN 'Completed'
        WHEN n <= 1900 THEN 'In_Progress'
        WHEN n <= 2150 THEN 'Approved'
        WHEN n <= 2400 THEN 'Pending'
        ELSE 'Rejected'
    END AS request_status,
    DATE_SUB('2026-10-25 10:00:00', INTERVAL (2500 - n) HOUR) AS created_at,
    CASE WHEN n <= 1500 THEN DATE_SUB('2026-10-28 17:00:00', INTERVAL (2500 - n) HOUR) ELSE NULL END AS resolved_at
FROM tmp_seq
WHERE n <= 2500;

-- -------------------------------------------------------------------------
-- BƯỚC 6: NẠP 10.000 BÚT TOÁN SỔ CÁI TÀI CHÍNH (FINANCIAL_LEDGER)
-- -------------------------------------------------------------------------
-- 6.1: 2.000 bút toán THU Tiền đặt cọc ('Deposit') gắn với 2.000 hợp đồng
INSERT INTO FINANCIAL_LEDGER (
    property_id, payer_id, payee_id, related_contract_id, related_request_id,
    transaction_type, category, amount, created_at
)
SELECT 
    lc.property_id,
    lc.tenant_id,
    p.landlord_id,
    lc.contract_id,
    NULL,
    'INCOME',
    'Deposit',
    lc.deposit_amount,
    DATE_ADD(lc.created_at, INTERVAL 1 HOUR)
FROM LEASE_CONTRACT lc
JOIN PROPERTY p ON lc.property_id = p.property_id;

-- 6.2: 4.500 bút toán THU Tiền thuê định kỳ ('Rent_Payment')
INSERT INTO FINANCIAL_LEDGER (
    property_id, payer_id, payee_id, related_contract_id, related_request_id,
    transaction_type, category, amount, created_at
)
SELECT 
    lc.property_id,
    lc.tenant_id,
    p.landlord_id,
    lc.contract_id,
    NULL,
    'INCOME',
    'Rent_Payment',
    lc.monthly_rent,
    DATE_SUB('2026-11-15 09:00:00', INTERVAL (6500 - s.n) HOUR)
FROM tmp_seq s
JOIN LEASE_CONTRACT lc ON lc.contract_id = 1 + (s.n % 1500)
JOIN PROPERTY p ON lc.property_id = p.property_id
WHERE s.n BETWEEN 2001 AND 6500;

-- 6.3: 1.500 bút toán CHI Phí bảo trì ('Maintenance_Cost') cho 1.500 phiếu Completed
INSERT INTO FINANCIAL_LEDGER (
    property_id, payer_id, payee_id, related_contract_id, related_request_id,
    transaction_type, category, amount, created_at
)
SELECT 
    mr.property_id,
    p.landlord_id,
    mr.tenant_id,
    NULL,
    mr.request_id,
    'EXPENSE',
    'Maintenance_Cost',
    mr.actual_cost,
    mr.resolved_at
FROM MAINTENANCE_REQUEST mr
JOIN PROPERTY p ON mr.property_id = p.property_id
WHERE mr.request_status = 'Completed';

-- 6.4: 1.600 bút toán CHI Hoa hồng môi giới ('Agent_Commission') cho hợp đồng qua môi giới
INSERT INTO FINANCIAL_LEDGER (
    property_id, payer_id, payee_id, related_contract_id, related_request_id,
    transaction_type, category, amount, created_at
)
SELECT 
    lc.property_id,
    p.landlord_id,
    lc.agent_id,
    lc.contract_id,
    NULL,
    'EXPENSE',
    'Agent_Commission',
    ROUND(lc.monthly_rent * (lc.commission_rate / 100.00), 2),
    DATE_ADD(lc.created_at, INTERVAL 2 HOUR)
FROM tmp_seq s
JOIN LEASE_CONTRACT lc ON lc.contract_id = 1 + (s.n % 2000)
JOIN PROPERTY p ON lc.property_id = p.property_id
WHERE s.n BETWEEN 8001 AND 10000
  AND lc.agent_id IS NOT NULL;

-- 6.5: 400 bút toán CHI Hoa hồng môi giới ('Agent_Commission') cho hợp đồng ký trực tiếp
INSERT INTO FINANCIAL_LEDGER (
    property_id, payer_id, payee_id, related_contract_id, related_request_id,
    transaction_type, category, amount, created_at
)
SELECT 
    lc.property_id,
    p.landlord_id,
    lc.agent_id,
    lc.contract_id,
    NULL,
    'EXPENSE',
    'Agent_Commission',
    ROUND(lc.monthly_rent * (lc.commission_rate / 100.00), 2),
    DATE_ADD(lc.created_at, INTERVAL 3 HOUR)
FROM tmp_seq s
JOIN LEASE_CONTRACT lc ON lc.contract_id = 1
JOIN PROPERTY p ON lc.property_id = p.property_id
WHERE s.n BETWEEN 8001 AND 10000
  AND (1 + (s.n % 2000)) % 5 = 0;

COMMIT;
DROP TEMPORARY TABLE IF EXISTS tmp_seq;