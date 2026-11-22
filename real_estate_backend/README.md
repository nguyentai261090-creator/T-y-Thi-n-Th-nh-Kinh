# 4.4 – System Integration (UI/Backend Integration)

Ứng dụng mẫu Flask kết nối MySQL database `real_estate_ledger`, viết theo schema của dự án Tây Thiên Thỉnh Kinh.

## Chức năng đã triển khai

1. **Tổng quan:** đọc số lượng bất động sản, hợp đồng Active, yêu cầu bảo trì Pending và tổng hợp tài chính.
2. **Danh sách bất động sản:** đọc từ View `vw_available_properties`.
3. **Báo cáo tài chính:** đọc từ View `vw_property_financial_summary`.
4. **Quản lý yêu cầu bảo trì:** xem danh sách và tạo mới bản ghi trong `MAINTENANCE_REQUEST`.

## Yêu cầu

- Python 3.10 trở lên.
- MySQL Server đang chạy.
- Database `real_estate_ledger` đã được tạo và đã chạy các file DDL, Data Insertion, Views.
- Tài khoản MySQL được phép SELECT các bảng/View được sử dụng và INSERT vào `MAINTENANCE_REQUEST`.

## Cài đặt trên Windows

Mở CMD/PowerShell tại thư mục chứa `app.py`:

```powershell
py -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

Sao chép `.env.example` thành `.env`, sau đó điền mật khẩu MySQL:

```env
DB_HOST=127.0.0.1
DB_PORT=3306
DB_NAME=real_estate_ledger
DB_USER=root
DB_PASSWORD=YOUR_MYSQL_PASSWORD
FLASK_SECRET_KEY=replace-with-a-long-random-secret
RUN_MODE=development
```

Không chia sẻ file `.env` hoặc commit file này lên Git.

## Chạy ứng dụng

```powershell
python run.py
```

Mở trình duyệt tại: http://127.0.0.1:5000

## Luồng tích hợp

`Browser UI (HTML/CSS) → Flask routes → db.py / MySQL Connector → MySQL real_estate_ledger → Flask → HTML response`.

Khi tạo yêu cầu bảo trì, giao diện gửi `contract_id`. Backend kiểm tra hợp đồng còn `Active`, lấy đúng `property_id` và `tenant_id`, kiểm tra dữ liệu đầu vào rồi INSERT bằng câu lệnh tham số hóa và `commit()`.

## Kiểm thử mục 4.4

1. Mở trang Tổng quan; đối chiếu số lượng với các truy vấn COUNT trong MySQL.
2. Mở Bất động sản; đối chiếu dữ liệu với `SELECT * FROM vw_available_properties LIMIT 100`.
3. Mở Tài chính; đối chiếu tổng thu/chi/dòng tiền với `vw_property_financial_summary`.
4. Mở Bảo trì → Tạo yêu cầu; chọn hợp đồng Active, nhập mô tả và chi phí rồi lưu.
5. Trong MySQL Workbench chạy:

```sql
SELECT request_id, property_id, tenant_id, description,
       estimated_cost, request_status, created_at
FROM MAINTENANCE_REQUEST
ORDER BY request_id DESC
LIMIT 5;
```

6. Xác nhận bản ghi vừa tạo xuất hiện trên giao diện Bảo trì và trong MySQL.

## Ảnh minh chứng nên chụp

- `4.4-01-dashboard.png`: trang tổng quan.
- `4.4-02-properties.png`: danh sách bất động sản đọc từ View.
- `4.4-03-financial.png`: báo cáo tài chính đọc từ View.
- `4.4-04-maintenance-form.png`: biểu mẫu tạo yêu cầu.
- `4.4-05-insert-result.png`: dữ liệu mới trong MySQL Workbench.

## Ghi chú

Ứng dụng này là bản demo tích hợp phục vụ đồ án, chưa triển khai đăng nhập/đăng xuất hay phân quyền giao diện. Phần RBAC/GRANT/REVOKE thuộc mục 5.2 của tài liệu phase, không nằm trong phạm vi 4.4.
