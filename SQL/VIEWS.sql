-- =========================================================================
-- VIEW 1: vw_available_properties
-- Mục đích: Cung cấp danh mục bất động sản đang ở trạng thái sẵn sàng giao dịch ('Available')
--           kèm thông tin liên hệ chủ sở hữu cho Môi giới (Agent) và Khách thuê (Tenant).
-- =========================================================================
CREATE OR REPLACE VIEW vw_available_properties AS
SELECT 
    p.property_id,
    p.title AS property_title,
    p.address AS property_address,
    p.rental_price,
    p.current_state,
    p.created_at AS listed_date,
    l.landlord_id,
    u.full_name AS landlord_name,
    u.phone_number AS landlord_phone,
    u.email AS landlord_email
FROM PROPERTY p
JOIN LANDLORD l ON p.landlord_id = l.landlord_id
JOIN USERS u ON l.landlord_id = u.user_id
WHERE p.current_state = 'Available';


-- =========================================================================
-- VIEW 2: vw_property_financial_summary
-- Mục đích: Báo cáo tổng hợp dòng tiền Thu (INCOME), Chi (EXPENSE) và Lợi nhuận ròng
--           tích lũy trên từng bất động sản dành cho Chủ sở hữu (Landlord) và Admin.
-- =========================================================================
CREATE OR REPLACE VIEW vw_property_financial_summary AS
SELECT 
    p.property_id,
    p.title AS property_title,
    p.landlord_id,
    u.full_name AS landlord_name,
    COUNT(fl.ledger_id) AS total_transactions,
    COALESCE(SUM(CASE WHEN fl.transaction_type = 'INCOME' THEN fl.amount ELSE 0.00 END), 0.00) AS total_income,
    COALESCE(SUM(CASE WHEN fl.transaction_type = 'EXPENSE' THEN fl.amount ELSE 0.00 END), 0.00) AS total_expense,
    COALESCE(SUM(CASE 
        WHEN fl.transaction_type = 'INCOME' THEN fl.amount 
        WHEN fl.transaction_type = 'EXPENSE' THEN -fl.amount 
        ELSE 0.00 
    END), 0.00) AS net_cashflow
FROM PROPERTY p
JOIN LANDLORD l ON p.landlord_id = l.landlord_id
JOIN USERS u ON l.landlord_id = u.user_id
LEFT JOIN FINANCIAL_LEDGER fl ON p.property_id = fl.property_id
GROUP BY p.property_id, p.title, p.landlord_id, u.full_name;