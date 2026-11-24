USE real_estate_ledger;

-- 1. Covering Index: Tìm kiếm nhà trống theo khung giá (tránh Key Lookup về bảng gốc)
DROP INDEX idx_property_state_price ON PROPERTY;
CREATE INDEX idx_property_state_price
ON PROPERTY (
    current_state,
    rental_price,
    property_id
);

-- 2. Kiểm tra hợp đồng hiệu lực (Active) theo bất động sản (BR4)
DROP INDEX idx_lease_property_status ON LEASE_CONTRACT;
CREATE INDEX idx_lease_property_status
    ON LEASE_CONTRACT (property_id, contract_status);

-- 3. Tra cứu hợp đồng theo khách thuê và thời hạn
DROP INDEX idx_lease_tenant_dates ON LEASE_CONTRACT;
CREATE INDEX idx_lease_tenant_dates
    ON LEASE_CONTRACT (tenant_id, start_date, end_date);

-- 4. Đối soát dòng tiền theo bất động sản và thời gian hạch toán (SO-04)
DROP INDEX idx_ledger_property_created ON FINANCIAL_LEDGER;
CREATE INDEX idx_ledger_property_created
    ON FINANCIAL_LEDGER (property_id, created_at);

-- 5. Thống kê dòng tiền theo người chi trả và người thụ hưởng
DROP INDEX idx_ledger_payer_payee ON FINANCIAL_LEDGER;
DROP INDEX idx_ledger_payee_created ON FINANCIAL_LEDGER;
CREATE INDEX idx_ledger_payer_payee
    ON FINANCIAL_LEDGER (payer_id, payee_id, created_at);
CREATE INDEX idx_ledger_payee_created
    ON FINANCIAL_LEDGER (payee_id, created_at);

-- 6. Theo dõi tiến độ phiếu yêu cầu bảo trì theo bất động sản
DROP INDEX idx_maint_property_status ON MAINTENANCE_REQUEST;
CREATE INDEX idx_maint_property_status
    ON MAINTENANCE_REQUEST (property_id, request_status);