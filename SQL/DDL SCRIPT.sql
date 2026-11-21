-- =========================================================================
-- ĐỀ TÀI: #10 Real Estate Property & Rental Ledger
-- NHÓM THỰC HIỆN: Tây Thiên Thỉnh Kinh
-- SQL DDL SCRIPTS (TABLES, INDEXES, VIEWS, TRIGGERS)
-- =========================================================================

DROP DATABASE IF EXISTS real_estate_ledger;
CREATE DATABASE real_estate_ledger
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE real_estate_ledger;

-- =========================================================================
-- PHẦN A: NHÓM PHÂN CẤP NGƯỜI DÙNG & PHÂN QUYỀN (USER HIERARCHY - OPTION 8A)
-- =========================================================================

-- 1. Bảng USERS (Siêu lớp người dùng cao nhất)
CREATE TABLE USERS (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL, -- Mật khẩu mã hóa an toàn (Encryption at Rest)
    phone_number VARCHAR(20) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) COMMENT = 'Lưu trữ toàn bộ thông tin định danh và tài khoản cơ bản của người dùng hệ thống.';

-- 2. Bảng AP (Authorized Personnel - Nhóm Vận hành & Quản trị)
CREATE TABLE AP (
    user_id INT PRIMARY KEY,
    employee_code VARCHAR(20) NOT NULL UNIQUE,
    access_level INT NOT NULL DEFAULT 1, -- 1: Staff, 2: Manager, 3: Admin
    CONSTRAINT fk_ap_users FOREIGN KEY (user_id)
        REFERENCES USERS(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_ap_emp_code CHECK (employee_code LIKE 'EMP-%'),
    CONSTRAINT chk_ap_access_level CHECK (access_level BETWEEN 1 AND 3)
) COMMENT = 'Tập hợp người dùng thuộc nhóm quản trị hệ thống và vận hành tòa nhà nội bộ.';

-- 3. Bảng ADMIN (Kỹ sư Quản trị Hệ thống - Subclass rời rạc từ AP)
CREATE TABLE ADMIN (
    admin_id INT PRIMARY KEY,
    system_config_rights VARCHAR(255) NOT NULL DEFAULT 'FULL_ACCESS',
    CONSTRAINT fk_admin_ap FOREIGN KEY (admin_id)
        REFERENCES AP(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) COMMENT = 'Kỹ sư hệ thống/CNTT chịu trách nhiệm an toàn dữ liệu và phân quyền.';

-- 4. Bảng PROPERTY_MANAGER (Nhân sự Quản lý Bất động sản - Subclass rời rạc từ AP)
CREATE TABLE PROPERTY_MANAGER (
    manager_id INT PRIMARY KEY,
    assigned_zone VARCHAR(100) NOT NULL,
    CONSTRAINT fk_manager_ap FOREIGN KEY (manager_id)
        REFERENCES AP(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) COMMENT = 'Nhân sự ban quản lý tòa nhà trực tiếp điều phối hiện trạng nhà, duyệt hợp đồng và bảo trì.';

-- 5. Bảng ATL (Authorized Transacting Leaders - Nhóm Khách hàng & Đối tác)
CREATE TABLE ATL (
    user_id INT PRIMARY KEY,
    identity_card_number VARCHAR(20) NOT NULL UNIQUE, -- Số CCCD/Hộ chiếu pháp lý
    address VARCHAR(255) NOT NULL,
    CONSTRAINT fk_atl_users FOREIGN KEY (user_id)
        REFERENCES USERS(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) COMMENT = 'Tập hợp người dùng trực tiếp tham gia giao dịch bất động sản thương mại.';

-- 6. Bảng AGENT (Nhân viên Môi giới Bất động sản - Subclass chồng lấn từ ATL)
CREATE TABLE AGENT (
    agent_id INT PRIMARY KEY,
    broker_license VARCHAR(50) NOT NULL,
    default_commission_rate DECIMAL(5,2) NOT NULL DEFAULT 5.00,
    CONSTRAINT fk_agent_atl FOREIGN KEY (agent_id)
        REFERENCES ATL(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_agent_comm_rate CHECK (default_commission_rate BETWEEN 0.00 AND 100.00)
) COMMENT = 'Nhân viên môi giới đóng vai trò trung gian kết nối chủ nhà và khách thuê.';

-- 7. Bảng TENANT (Khách thuê Bất động sản - Subclass chồng lấn từ ATL)
CREATE TABLE TENANT (
    tenant_id INT PRIMARY KEY,
    emergency_contact VARCHAR(20) NOT NULL,
    CONSTRAINT fk_tenant_atl FOREIGN KEY (tenant_id)
        REFERENCES ATL(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) COMMENT = 'Khách thuê trực tiếp ký hợp đồng, sử dụng mặt bằng và gửi yêu cầu bảo trì.';

-- 8. Bảng LANDLORD (Chủ sở hữu Bất động sản - Subclass chồng lấn từ ATL)
CREATE TABLE LANDLORD (
    landlord_id INT PRIMARY KEY,
    bank_account_number VARCHAR(30) NOT NULL,
    bank_name VARCHAR(100) NOT NULL,
    tax_code VARCHAR(20) NOT NULL,
    CONSTRAINT fk_landlord_atl FOREIGN KEY (landlord_id)
        REFERENCES ATL(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) COMMENT = 'Chủ sở hữu hợp pháp đối với bất động sản niêm yết trên hệ thống (BR1).';


-- =========================================================================
-- PHẦN B: NHÓM THỰC THỂ NGHIỆP VỤ VẬN HÀNH & SỔ CÁI TÀI CHÍNH
-- =========================================================================

-- 9. Bảng PROPERTY (Danh mục Bất động sản - Thực thể trung tâm)
CREATE TABLE PROPERTY (
    property_id INT AUTO_INCREMENT PRIMARY KEY,
    landlord_id INT NOT NULL,
    title VARCHAR(255) NOT NULL,
    address VARCHAR(255) NOT NULL,
    current_state VARCHAR(30) NOT NULL DEFAULT 'Available',
    rental_price DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_property_landlord FOREIGN KEY (landlord_id)
        REFERENCES LANDLORD(landlord_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_property_state CHECK (current_state IN ('Available', 'Leased', 'Under Maintenance')),
    CONSTRAINT chk_property_price CHECK (rental_price > 0.00)
) COMMENT = 'Thực thể trung tâm quản lý danh mục bất động sản và vòng đời trạng thái (BR1, BR2).';

-- 10. Bảng PROPERTY_STATE_HISTORY (Nhật ký Chuyển đổi Trạng thái Tài sản)
CREATE TABLE PROPERTY_STATE_HISTORY (
    history_id INT AUTO_INCREMENT PRIMARY KEY,
    property_id INT NOT NULL,
    changed_by INT NOT NULL,
    old_state VARCHAR(30) NOT NULL,
    new_state VARCHAR(30) NOT NULL,
    change_reason VARCHAR(255) NOT NULL,
    changed_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_history_property FOREIGN KEY (property_id)
        REFERENCES PROPERTY(property_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_history_manager FOREIGN KEY (changed_by)
        REFERENCES PROPERTY_MANAGER(manager_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_history_old_state CHECK (old_state IN ('Available', 'Leased', 'Under Maintenance')),
    CONSTRAINT chk_history_new_state CHECK (new_state IN ('Available', 'Leased', 'Under Maintenance'))
) COMMENT = 'Lưu trữ toàn bộ vết lịch sử chuyển đổi trạng thái tài sản phục vụ kiểm toán (BR2).';

-- 11. Bảng LEASE_CONTRACT (Hợp đồng Cho thuê Bất động sản)
CREATE TABLE LEASE_CONTRACT (
    contract_id INT AUTO_INCREMENT PRIMARY KEY,
    property_id INT NOT NULL,
    tenant_id INT NOT NULL,
    agent_id INT NULL, -- Cho phép NULL nếu khách thuê ký kết trực tiếp với chủ nhà
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    monthly_rent DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    deposit_amount DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    commission_rate DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    contract_status VARCHAR(20) NOT NULL DEFAULT 'Draft',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_contract_property FOREIGN KEY (property_id)
        REFERENCES PROPERTY(property_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_contract_tenant FOREIGN KEY (tenant_id)
        REFERENCES TENANT(tenant_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_contract_agent FOREIGN KEY (agent_id)
        REFERENCES AGENT(agent_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_contract_dates CHECK (end_date > start_date), -- BR4
    CONSTRAINT chk_contract_rent CHECK (monthly_rent > 0.00),
    CONSTRAINT chk_contract_deposit CHECK (deposit_amount >= 0.00),
    CONSTRAINT chk_contract_comm CHECK (commission_rate BETWEEN 0.00 AND 100.00),
    CONSTRAINT chk_contract_status CHECK (contract_status IN ('Draft', 'Active', 'Terminated', 'Expired'))
) COMMENT = 'Văn bản thỏa thuận pháp lý cho thuê bất động sản giữa các bên (BR4).';

-- 12. Bảng MAINTENANCE_REQUEST (Yêu cầu Bảo trì & Sửa chữa)
CREATE TABLE MAINTENANCE_REQUEST (
    request_id INT AUTO_INCREMENT PRIMARY KEY,
    property_id INT NOT NULL,
    tenant_id INT NOT NULL,
    assigned_manager_id INT NULL,
    description VARCHAR(255) NOT NULL,
    estimated_cost DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    actual_cost DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    request_status VARCHAR(20) NOT NULL DEFAULT 'Pending',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at DATETIME NULL,
    CONSTRAINT fk_maint_property FOREIGN KEY (property_id)
        REFERENCES PROPERTY(property_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_maint_tenant FOREIGN KEY (tenant_id)
        REFERENCES TENANT(tenant_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_maint_manager FOREIGN KEY (assigned_manager_id)
        REFERENCES PROPERTY_MANAGER(manager_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_maint_est_cost CHECK (estimated_cost >= 0.00),
    CONSTRAINT chk_maint_act_cost CHECK (actual_cost >= 0.00),
    CONSTRAINT chk_maint_status CHECK (request_status IN ('Pending', 'Approved', 'In_Progress', 'Completed', 'Rejected'))
) COMMENT = 'Phiếu ghi nhận sự cố hỏng hóc kỹ thuật và quyết toán chi phí sửa chữa.';

-- 13. Bảng FINANCIAL_LEDGER (Sổ cái Tài chính Bất biến - Append-Only Ledger)
CREATE TABLE FINANCIAL_LEDGER (
    ledger_id INT AUTO_INCREMENT PRIMARY KEY,
    property_id INT NOT NULL,
    payer_id INT NOT NULL,
    payee_id INT NOT NULL,
    related_contract_id INT NULL,
    related_request_id INT NULL,
    transaction_type VARCHAR(20) NOT NULL,
    category VARCHAR(50) NOT NULL,
    amount DECIMAL(12,2) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ledger_property FOREIGN KEY (property_id)
        REFERENCES PROPERTY(property_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ledger_payer FOREIGN KEY (payer_id)
        REFERENCES ATL(user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ledger_payee FOREIGN KEY (payee_id)
        REFERENCES ATL(user_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_ledger_contract FOREIGN KEY (related_contract_id)
        REFERENCES LEASE_CONTRACT(contract_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_ledger_request FOREIGN KEY (related_request_id)
        REFERENCES MAINTENANCE_REQUEST(request_id)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT chk_ledger_type CHECK (transaction_type IN ('INCOME', 'EXPENSE')),
    CONSTRAINT chk_ledger_category CHECK (category IN ('Deposit', 'Rent_Payment', 'Maintenance_Cost', 'Agent_Commission')),
    CONSTRAINT chk_ledger_amount CHECK (amount > 0.00)
) COMMENT = 'Sổ cái bất biến (Append-only) lưu trữ mọi dòng tiền thu/chi phục vụ đối soát và kiểm toán (BR3).';