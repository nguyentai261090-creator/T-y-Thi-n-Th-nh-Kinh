USE real_estate_ledger;


#1: Danh sách bất động sản đang cho thuê
#Yêu cầu: Hiển thị tên nhà, địa chỉ, giá thuê, trạng thái và thông tin liên hệ của chủ nhà.

SELECT
    p.property_id,
    p.title,
    p.address,
    p.rental_price,
    u.full_name AS landlord_name,
    u.phone_number,
    u.email
FROM PROPERTY p
JOIN LANDLORD l
    ON p.landlord_id = l.landlord_id
JOIN USERS u
    ON l.landlord_id = u.user_id
WHERE p.current_state = 'Available'
ORDER BY p.rental_price ASC;


#2: Thống kê số lượng bất động sản của từng chủ nhà
#Yêu cầu: Hiển thị chủ nhà, số bất động sản đang sở hữu, giá thuê trung bình và tổng giá thuê.

SELECT
    l.landlord_id,
    u.full_name,
    COUNT(p.property_id) AS total_properties,
    COALESCE(AVG(p.rental_price), 0) AS average_rent,
    COALESCE(SUM(p.rental_price), 0) AS total_rent
FROM LANDLORD l
JOIN USERS u
    ON l.landlord_id = u.user_id
LEFT JOIN PROPERTY p
    ON l.landlord_id = p.landlord_id
GROUP BY l.landlord_id, u.full_name
ORDER BY total_properties DESC;



#3: Thống kê số hợp đồng của từng khách thuê

SELECT
    t.tenant_id,
    u.full_name,
    COUNT(lc.contract_id) AS total_contracts,
    SUM(
        CASE
            WHEN lc.contract_status = 'Active' THEN 1
            ELSE 0
        END
    ) AS active_contracts,
    COALESCE(
        SUM(
            CASE
                WHEN lc.contract_status = 'Active'
                THEN lc.monthly_rent
                ELSE 0
            END
        ), 0
    ) AS total_active_rent
FROM TENANT t
JOIN USERS u
    ON t.tenant_id = u.user_id
LEFT JOIN LEASE_CONTRACT lc
    ON t.tenant_id = lc.tenant_id
GROUP BY t.tenant_id, u.full_name
ORDER BY total_contracts DESC;


#4: Hiển thị thông tin chi tiết hợp đồng thuê

SELECT
    lc.contract_id,
    p.title AS property_name,
    tenant.full_name AS tenant_name,
    landlord.full_name AS landlord_name,
    agent_user.full_name AS agent_name,
    lc.start_date,
    lc.end_date,
    lc.monthly_rent,
    lc.deposit_amount,
    lc.contract_status
FROM LEASE_CONTRACT lc
JOIN PROPERTY p
    ON lc.property_id = p.property_id
JOIN TENANT t
    ON lc.tenant_id = t.tenant_id
JOIN USERS tenant
    ON t.tenant_id = tenant.user_id
JOIN LANDLORD l
    ON p.landlord_id = l.landlord_id
JOIN USERS landlord
    ON l.landlord_id = landlord.user_id
LEFT JOIN AGENT a
    ON lc.agent_id = a.agent_id
LEFT JOIN USERS agent_user
    ON a.agent_id = agent_user.user_id
ORDER BY lc.created_at DESC;


#5: Tìm bất động sản chưa có hợp đồng thuê hiệu lực

SELECT
    p.property_id,
    p.title,
    p.address,
    p.rental_price
FROM PROPERTY p
WHERE p.current_state = 'Available'
AND NOT EXISTS (
    SELECT 1
    FROM LEASE_CONTRACT lc
    WHERE lc.property_id = p.property_id
      AND lc.contract_status = 'Active'
);


#6: Thống kê hoạt động bảo trì theo từng bất động sản

SELECT
    p.property_id,
    p.title,
    COUNT(mr.request_id) AS total_requests,
    SUM(
        CASE WHEN mr.request_status = 'Completed'
        THEN 1 ELSE 0 END
    ) AS completed_requests,
    SUM(
        CASE WHEN mr.request_status = 'Pending'
        THEN 1 ELSE 0 END
    ) AS pending_requests,
    COALESCE(
        SUM(
            CASE WHEN mr.request_status = 'Completed'
            THEN mr.actual_cost ELSE 0 END
        ), 0
    ) AS total_maintenance_cost
FROM PROPERTY p
LEFT JOIN MAINTENANCE_REQUEST mr
    ON p.property_id = mr.property_id
GROUP BY p.property_id, p.title
HAVING COUNT(mr.request_id) > 0
ORDER BY total_maintenance_cost DESC;



#7: Đánh giá hiệu suất làm việc của nhân viên môi giới
#Yêu cầu: Thống kê số hợp đồng, số hợp đồng đang hoạt động và tổng hoa hồng được ghi nhận.

SELECT
    a.agent_id,
    u.full_name,
    COALESCE(c.total_contracts, 0) AS total_contracts,
    COALESCE(c.active_contracts, 0) AS active_contracts,
    COALESCE(f.total_commission, 0) AS total_commission
FROM AGENT a
JOIN USERS u
    ON a.agent_id = u.user_id
LEFT JOIN (
    SELECT
        agent_id,
        COUNT(*) AS total_contracts,
        SUM(
            CASE WHEN contract_status = 'Active'
            THEN 1 ELSE 0 END
        ) AS active_contracts
    FROM LEASE_CONTRACT
    WHERE agent_id IS NOT NULL
    GROUP BY agent_id
) c ON a.agent_id = c.agent_id
LEFT JOIN (
    SELECT
        payee_id,
        SUM(amount) AS total_commission
    FROM FINANCIAL_LEDGER
    WHERE category = 'Agent_Commission'
    GROUP BY payee_id
) f ON a.agent_id = f.payee_id
ORDER BY total_contracts DESC;



#8: Thống kê thu nhập và chi phí của từng chủ nhà

SELECT
    l.landlord_id,
    u.full_name,
    COUNT(DISTINCT p.property_id) AS total_properties,
    COALESCE(
        SUM(
            CASE WHEN fl.transaction_type = 'INCOME'
            THEN fl.amount ELSE 0 END
        ), 0
    ) AS total_income,
    COALESCE(
        SUM(
            CASE WHEN fl.transaction_type = 'EXPENSE'
            THEN fl.amount ELSE 0 END
        ), 0
    ) AS total_expense,
    COALESCE(
        SUM(
            CASE
                WHEN fl.transaction_type = 'INCOME'
                    THEN fl.amount
                WHEN fl.transaction_type = 'EXPENSE'
                    THEN -fl.amount
                ELSE 0
            END
        ), 0
    ) AS net_cashflow
FROM LANDLORD l
JOIN USERS u
    ON l.landlord_id = u.user_id
LEFT JOIN PROPERTY p
    ON l.landlord_id = p.landlord_id
LEFT JOIN FINANCIAL_LEDGER fl
    ON p.property_id = fl.property_id
GROUP BY l.landlord_id, u.full_name
ORDER BY net_cashflow DESC;



#9: Top 10 khách thuê có tổng tiền thuê đã thanh toán cao nhất

SELECT
    t.tenant_id,
    u.full_name,
    COUNT(fl.ledger_id) AS total_payments,
    SUM(fl.amount) AS total_rent_paid,
    MAX(fl.created_at) AS last_payment
FROM TENANT t
JOIN USERS u
    ON t.tenant_id = u.user_id
JOIN FINANCIAL_LEDGER fl
    ON t.tenant_id = fl.payer_id
WHERE fl.category = 'Rent_Payment'
AND fl.transaction_type = 'INCOME'
GROUP BY t.tenant_id, u.full_name
ORDER BY total_rent_paid DESC
LIMIT 10;


#10: Tìm lịch sử thay đổi trạng thái gần nhất của từng bất động sản

SELECT
    p.property_id,
    p.title,
    h.old_state,
    h.new_state,
    h.change_reason,
    h.changed_at,
    u.full_name AS manager_name
FROM PROPERTY p
JOIN (
    SELECT
        property_id,
        MAX(changed_at) AS latest_change
    FROM PROPERTY_STATE_HISTORY
    GROUP BY property_id
) latest
    ON p.property_id = latest.property_id
JOIN PROPERTY_STATE_HISTORY h
    ON h.property_id = latest.property_id
    AND h.changed_at = latest.latest_change
JOIN PROPERTY_MANAGER pm
    ON h.changed_by = pm.manager_id
JOIN USERS u
    ON pm.manager_id = u.user_id
ORDER BY h.changed_at DESC;


#11: Tìm các bất động sản có giá thuê cao hơn mức trung bình toàn hệ thống

SELECT
    p.property_id,
    p.title,
    p.rental_price,
    u.full_name AS landlord_name
FROM PROPERTY p
JOIN LANDLORD l
    ON p.landlord_id = l.landlord_id
JOIN USERS u
    ON l.landlord_id = u.user_id
WHERE p.rental_price > (
    SELECT AVG(rental_price)
    FROM PROPERTY
)
ORDER BY p.rental_price DESC;



#12: Danh sách các yêu cầu bảo trì chưa hoàn thành

SELECT
    mr.request_id,
    p.title AS property_name,
    tenant.full_name AS tenant_name,
    manager.full_name AS manager_name,
    mr.description,
    mr.estimated_cost,
    mr.request_status,
    mr.created_at
FROM MAINTENANCE_REQUEST mr
JOIN PROPERTY p
    ON mr.property_id = p.property_id
JOIN TENANT t
    ON mr.tenant_id = t.tenant_id
JOIN USERS tenant
    ON t.tenant_id = tenant.user_id
LEFT JOIN PROPERTY_MANAGER pm
    ON mr.assigned_manager_id = pm.manager_id
LEFT JOIN USERS manager
    ON pm.manager_id = manager.user_id
WHERE mr.request_status IN (
    'Pending',
    'Approved',
    'In_Progress'
)
ORDER BY mr.created_at ASC;




