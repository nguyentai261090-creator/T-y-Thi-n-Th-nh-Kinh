DELIMITER //

-- =========================================================================
-- TRIGGER 1: trg_prevent_ledger_modification (Thực thi BR3: Append-Only Ledger)
-- Mục đích: Ngăn chặn tuyệt đối mọi hành vi chỉnh sửa (UPDATE) hoặc xóa (DELETE)
--           dữ liệu trên sổ cái FINANCIAL_LEDGER để bảo toàn dấu vết kiểm toán.
-- =========================================================================
CREATE TRIGGER trg_prevent_ledger_update
BEFORE UPDATE ON FINANCIAL_LEDGER
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'VI PHẠM BR3: Sổ cái tài chính (FINANCIAL_LEDGER) là bất biến (Append-Only), nghiêm cấm thao tác UPDATE!';
END //

CREATE TRIGGER trg_prevent_ledger_delete
BEFORE DELETE ON FINANCIAL_LEDGER
FOR EACH ROW
BEGIN
    SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'VI PHẠM BR3: Sổ cái tài chính (FINANCIAL_LEDGER) là bất biến (Append-Only), nghiêm cấm thao tác DELETE!';
END //


-- =========================================================================
-- TRIGGER 2: trg_validate_and_activate_lease (Thực thi BR2, BR4, BR5)
-- Mục đích: 
--   1. Kiểm tra bất động sản phải đang ở trạng thái 'Available' và chưa có hợp đồng
--      'Active' nào khác trước khi kích hoạt hợp đồng mới (BR2, BR4).
--   2. Khi hợp đồng chuyển sang 'Active', tự động cập nhật trạng thái tài sản sang
--      'Leased', ghi nhận tiền đặt cọc (Deposit) và tự động trích lập khoản chi hoa
--      hồng môi giới (Agent_Commission) vào sổ cái tài chính (BR5).
-- =========================================================================
CREATE TRIGGER trg_before_lease_activate
BEFORE UPDATE ON LEASE_CONTRACT
FOR EACH ROW
BEGIN
    DECLARE v_current_state VARCHAR(30);
    DECLARE v_active_count INT;

    IF NEW.contract_status = 'Active' AND OLD.contract_status <> 'Active' THEN
        -- Kiểm tra trạng thái hiện tại của bất động sản (BR2)
        SELECT current_state INTO v_current_state
        FROM PROPERTY
        WHERE property_id = NEW.property_id;

        IF v_current_state <> 'Available' THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'VI PHẠM BR2: Bất động sản không ở trạng thái Available nên không thể kích hoạt hợp đồng thuê!';
        END IF;

        -- Kiểm tra không tồn tại hợp đồng Active trùng lặp trên cùng tài sản (BR4)
        SELECT COUNT(*) INTO v_active_count
        FROM LEASE_CONTRACT
        WHERE property_id = NEW.property_id 
          AND contract_status = 'Active'
          AND contract_id <> NEW.contract_id;

        IF v_active_count > 0 THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'VI PHẠM BR4: Bất động sản này đang có hợp đồng thuê Active khác có hiệu lực!';
        END IF;
    END IF;
END //

CREATE TRIGGER trg_after_lease_activate
AFTER UPDATE ON LEASE_CONTRACT
FOR EACH ROW
BEGIN
    DECLARE v_landlord_id INT;
    DECLARE v_commission_amount DECIMAL(12,2);

    IF NEW.contract_status = 'Active' AND OLD.contract_status <> 'Active' THEN
        -- Lấy mã chủ sở hữu bất động sản
        SELECT landlord_id INTO v_landlord_id
        FROM PROPERTY
        WHERE property_id = NEW.property_id;

        -- 1. Chuyển trạng thái bất động sản sang 'Leased' (BR2)
        UPDATE PROPERTY
        SET current_state = 'Leased'
        WHERE property_id = NEW.property_id;

        -- 2. Hạch toán khoản thu Tiền đặt cọc (Deposit) nếu deposit_amount > 0 (BR5)
        IF NEW.deposit_amount > 0.00 THEN
            INSERT INTO FINANCIAL_LEDGER (
                property_id, payer_id, payee_id, related_contract_id,
                transaction_type, category, amount
            ) VALUES (
                NEW.property_id, NEW.tenant_id, v_landlord_id, NEW.contract_id,
                'INCOME', 'Deposit', NEW.deposit_amount
            );
        END IF;

        -- 3. Tự động trích lập khoản chi Hoa hồng môi giới nếu có Agent và tỷ lệ > 0 (BR5)
        IF NEW.agent_id IS NOT NULL AND NEW.commission_rate > 0.00 THEN
            SET v_commission_amount = ROUND(NEW.monthly_rent * (NEW.commission_rate / 100.00), 2);
            
            IF v_commission_amount > 0.00 THEN
                INSERT INTO FINANCIAL_LEDGER (
                    property_id, payer_id, payee_id, related_contract_id,
                    transaction_type, category, amount
                ) VALUES (
                    NEW.property_id, v_landlord_id, NEW.agent_id, NEW.contract_id,
                    'EXPENSE', 'Agent_Commission', v_commission_amount
                );
            END IF;
        END IF;
    END IF;
END //

DELIMITER ;