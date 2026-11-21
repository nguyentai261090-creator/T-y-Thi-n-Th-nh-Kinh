-- =========================================================================
-- ĐỀ TÀI: #10 Real Estate Property & Rental Ledger
-- NHÓM THỰC HIỆN: Tây Thiên Thỉnh Kinh
-- =========================================================================

USE real_estate_ledger;

-- -------------------------------------------------------------------------
-- BƯỚC 0: CẬP NHẬT THỐNG KÊ CHỈ MỤC & BẢNG (INNODB STATISTICS)
-- Mục đích: Đảm bảo bộ tối ưu (Optimizer) nhận diện đủ 23.900 dòng mới nạp
-- -------------------------------------------------------------------------
ANALYZE TABLE 
    USERS, AP, ADMIN, PROPERTY_MANAGER, 
    ATL, AGENT, LANDLORD, TENANT, 
    PROPERTY, PROPERTY_STATE_HISTORY, 
    LEASE_CONTRACT, MAINTENANCE_REQUEST, FINANCIAL_LEDGER;

-- -------------------------------------------------------------------------
-- BƯỚC 1: THỐNG KÊ CHÍNH XÁC SỐ LƯỢNG BẢN GHI CỦA TOÀN BỘ 13 BẢNG
-- Kỳ vọng: Tổng cộng đúng 23.900 bản ghi trên toàn hệ thống.
-- -------------------------------------------------------------------------
SELECT '01. USERS' AS Ten_Bang, COUNT(*) AS So_Ban_Ghi FROM USERS
UNION ALL SELECT '02. AP', COUNT(*) FROM AP
UNION ALL SELECT '03. ADMIN', COUNT(*) FROM ADMIN
UNION ALL SELECT '04. PROPERTY_MANAGER', COUNT(*) FROM PROPERTY_MANAGER
UNION ALL SELECT '05. ATL', COUNT(*) FROM ATL
UNION ALL SELECT '06. AGENT', COUNT(*) FROM AGENT
UNION ALL SELECT '07. LANDLORD', COUNT(*) FROM LANDLORD
UNION ALL SELECT '08. TENANT', COUNT(*) FROM TENANT
UNION ALL SELECT '09. PROPERTY', COUNT(*) FROM PROPERTY
UNION ALL SELECT '10. PROPERTY_STATE_HISTORY', COUNT(*) FROM PROPERTY_STATE_HISTORY
UNION ALL SELECT '11. LEASE_CONTRACT', COUNT(*) FROM LEASE_CONTRACT
UNION ALL SELECT '12. MAINTENANCE_REQUEST', COUNT(*) FROM MAINTENANCE_REQUEST
UNION ALL SELECT '13. FINANCIAL_LEDGER', COUNT(*) FROM FINANCIAL_LEDGER
UNION ALL SELECT '>>> TỔNG CỘNG TOÀN CSDL',
    (SELECT COUNT(*) FROM USERS) + (SELECT COUNT(*) FROM AP) + (SELECT COUNT(*) FROM ADMIN) +
    (SELECT COUNT(*) FROM PROPERTY_MANAGER) + (SELECT COUNT(*) FROM ATL) + (SELECT COUNT(*) FROM AGENT) +
    (SELECT COUNT(*) FROM LANDLORD) + (SELECT COUNT(*) FROM TENANT) + (SELECT COUNT(*) FROM PROPERTY) +
    (SELECT COUNT(*) FROM PROPERTY_STATE_HISTORY) + (SELECT COUNT(*) FROM LEASE_CONTRACT) +
    (SELECT COUNT(*) FROM MAINTENANCE_REQUEST) + (SELECT COUNT(*) FROM FINANCIAL_LEDGER);

-- -------------------------------------------------------------------------
-- BƯỚC 2: KIỂM CHỨNG CÁC KỊCH BẢN BIÊN (EDGE CASES) & QUY TẮC NGHIỆP VỤ
-- Kỳ vọng: 20 Chủ nhà chưa có nhà, 100 Nhà chưa bảo trì, 400 HĐ ký trực tiếp,
--          500 Nhà Leased, 500 HĐ Active (BR4).
-- -------------------------------------------------------------------------
SELECT 
    (SELECT COUNT(*) FROM LANDLORD l LEFT JOIN PROPERTY p ON l.landlord_id = p.landlord_id WHERE p.property_id IS NULL) AS Chu_Nha_Chua_Co_Nha,
    (SELECT COUNT(*) FROM PROPERTY p WHERE NOT EXISTS (SELECT 1 FROM MAINTENANCE_REQUEST m WHERE m.property_id = p.property_id)) AS Nha_Chua_Tung_Bao_Tri,
    (SELECT COUNT(*) FROM LEASE_CONTRACT WHERE agent_id IS NULL) AS Hop_Dong_Ky_Truc_Tiep,
    (SELECT COUNT(*) FROM PROPERTY WHERE current_state = 'Leased') AS So_Nha_Dang_Thue,
    (SELECT COUNT(*) FROM LEASE_CONTRACT WHERE contract_status = 'Active') AS So_Hop_Dong_Active;

-- -------------------------------------------------------------------------
-- BƯỚC 4: KIỂM THỬ TỐC ĐỘ TRUY VẤN TRÊN 10.000 DÒNG SỔ CÁI (MỤC TIÊU SO-04)
-- Lưu ý hiển thị: Kết quả trả về 1 ô văn bản phân tích hiệu năng (EXPLAIN).
-- Bấm nút "IA" (Wrap Cell Content) ở Result Grid để xem trọn vẹn actual time < 200ms.
-- -------------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT * FROM vw_property_financial_summary
WHERE net_cashflow > 50000000
ORDER BY net_cashflow DESC
LIMIT 20;
