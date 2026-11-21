-- 1. Chỉ mục kết hợp phục vụ tìm kiếm danh sách nhà trống theo khung giá thuê (Môi giới & Khách thuê)
CREATE INDEX idx_property_state_price 
    ON PROPERTY(current_state, rental_price);

-- 2. Chỉ mục tối ưu hóa kiểm tra hợp đồng hiệu lực (Active) theo từng bất động sản (BR4)
CREATE INDEX idx_lease_property_status 
    ON LEASE_CONTRACT(property_id, contract_status);

-- 3. Chỉ mục phục vụ tra cứu hợp đồng theo khách thuê và thời hạn
CREATE INDEX idx_lease_tenant_dates 
    ON LEASE_CONTRACT(tenant_id, start_date, end_date);

-- 4. Chỉ mục tối ưu truy vấn đối soát dòng tiền theo bất động sản và thời gian hạch toán (SO-04)
CREATE INDEX idx_ledger_property_created 
    ON FINANCIAL_LEDGER(property_id, created_at);

-- 5. Chỉ mục tối ưu thống kê dòng tiền theo người chi trả và người thụ hưởng
CREATE INDEX idx_ledger_payer_payee 
    ON FINANCIAL_LEDGER(payer_id, payee_id);

-- 6. Chỉ mục tối ưu theo dõi tiến độ xử lý các phiếu yêu cầu bảo trì
CREATE INDEX idx_maint_property_status 
    ON MAINTENANCE_REQUEST(property_id, request_status);