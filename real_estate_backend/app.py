import os
from decimal import Decimal, InvalidOperation

from flask import Flask, flash, redirect, render_template, request, url_for
from mysql.connector import Error as MySQLError

from db import execute_insert, fetch_all, fetch_one

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "change-this-local-development-key")
app.config["MAX_CONTENT_LENGTH"] = 1 * 1024 * 1024


@app.template_filter("vnd")
def format_vnd(value):
    try:
        return f"{Decimal(str(value or 0)):,.0f} đ"
    except (InvalidOperation, TypeError, ValueError):
        return "0 đ"


@app.route("/")
def dashboard():
    stats = fetch_one(
        """
        SELECT
            (SELECT COUNT(*) FROM PROPERTY) AS total_properties,
            (SELECT COUNT(*) FROM PROPERTY WHERE current_state = 'Available') AS available_properties,
            (SELECT COUNT(*) FROM LEASE_CONTRACT WHERE contract_status = 'Active') AS active_contracts,
            (SELECT COUNT(*) FROM MAINTENANCE_REQUEST WHERE request_status = 'Pending') AS pending_requests
        """
    )
    finance = fetch_one(
        """
        SELECT
            COALESCE(SUM(total_income), 0) AS total_income,
            COALESCE(SUM(total_expense), 0) AS total_expense,
            COALESCE(SUM(net_cashflow), 0) AS net_cashflow
        FROM vw_property_financial_summary
        """
    )
    recent_requests = fetch_all(
        """
        SELECT mr.request_id, p.title AS property_title,
               mr.description, mr.request_status, mr.created_at,
               u.full_name AS tenant_name
        FROM MAINTENANCE_REQUEST mr
        JOIN PROPERTY p ON p.property_id = mr.property_id
        JOIN TENANT t ON t.tenant_id = mr.tenant_id
        JOIN USERS u ON u.user_id = t.tenant_id
        ORDER BY mr.created_at DESC, mr.request_id DESC
        LIMIT 6
        """
    )
    return render_template(
        "index.html", stats=stats, finance=finance,
        recent_requests=recent_requests
    )


@app.route("/properties")
def properties():
    keyword = request.args.get("q", "").strip()
    if keyword:
        pattern = f"%{keyword}%"
        rows = fetch_all(
            """
            SELECT property_id, property_title, property_address, rental_price,
                   current_state, landlord_name, landlord_phone, landlord_email
            FROM vw_available_properties
            WHERE property_title LIKE %s OR property_address LIKE %s
            ORDER BY property_id DESC
            LIMIT 100
            """,
            (pattern, pattern),
        )
    else:
        rows = fetch_all(
            """
            SELECT property_id, property_title, property_address, rental_price,
                   current_state, landlord_name, landlord_phone, landlord_email
            FROM vw_available_properties
            ORDER BY property_id DESC
            LIMIT 100
            """
        )
    return render_template("properties.html", properties=rows, keyword=keyword)


@app.route("/financial")
def financial():
    rows = fetch_all(
        """
        SELECT property_id, property_title, landlord_name,
               total_transactions, total_income, total_expense, net_cashflow
        FROM vw_property_financial_summary
        ORDER BY net_cashflow DESC
        LIMIT 100
        """
    )
    totals = fetch_one(
        """
        SELECT COALESCE(SUM(total_income), 0) AS total_income,
               COALESCE(SUM(total_expense), 0) AS total_expense,
               COALESCE(SUM(net_cashflow), 0) AS net_cashflow
        FROM vw_property_financial_summary
        """
    )
    return render_template("financial.html", rows=rows, totals=totals)


@app.route("/maintenance")
def maintenance_list():
    rows = fetch_all(
        """
        SELECT mr.request_id, mr.description, mr.estimated_cost,
               mr.actual_cost, mr.request_status, mr.created_at,
               p.title AS property_title,
               tenant.full_name AS tenant_name,
               manager.full_name AS manager_name
        FROM MAINTENANCE_REQUEST mr
        JOIN PROPERTY p ON p.property_id = mr.property_id
        JOIN TENANT t ON t.tenant_id = mr.tenant_id
        JOIN USERS tenant ON tenant.user_id = t.tenant_id
        LEFT JOIN PROPERTY_MANAGER pm ON pm.manager_id = mr.assigned_manager_id
        LEFT JOIN USERS manager ON manager.user_id = pm.manager_id
        ORDER BY mr.created_at DESC, mr.request_id DESC
        LIMIT 100
        """
    )
    return render_template("maintenance.html", requests=rows)


def get_active_contract_options():
    """Return valid property/tenant pairs taken from active lease contracts."""
    return fetch_all(
        """
        SELECT lc.contract_id, lc.property_id, lc.tenant_id,
               p.title AS property_title,
               tenant.full_name AS tenant_name
        FROM LEASE_CONTRACT lc
        JOIN PROPERTY p ON p.property_id = lc.property_id
        JOIN TENANT t ON t.tenant_id = lc.tenant_id
        JOIN USERS tenant ON tenant.user_id = t.tenant_id
        WHERE lc.contract_status = 'Active'
        ORDER BY lc.contract_id DESC
        LIMIT 500
        """
    )


@app.route("/maintenance/new", methods=["GET", "POST"])
def maintenance_new():
    contracts = get_active_contract_options()

    if request.method == "POST":
        try:
            contract_id = int(request.form.get("contract_id", ""))
        except (TypeError, ValueError):
            flash("Vui lòng chọn hợp đồng hợp lệ.", "error")
            return render_template("maintenance_form.html", contracts=contracts)

        description = request.form.get("description", "").strip()
        raw_cost = request.form.get("estimated_cost", "").strip()

        if not description or len(description) > 255:
            flash("Mô tả không được để trống và tối đa 255 ký tự.", "error")
            return render_template("maintenance_form.html", contracts=contracts)

        try:
            estimated_cost = Decimal(raw_cost)
            if not estimated_cost.is_finite() or estimated_cost < 0 or estimated_cost > Decimal("9999999999.99"):
                raise InvalidOperation
            estimated_cost = estimated_cost.quantize(Decimal("0.01"))
        except (InvalidOperation, ValueError):
            flash("Chi phí dự kiến phải là số không âm, tối đa 2 chữ số thập phân.", "error")
            return render_template("maintenance_form.html", contracts=contracts)

        contract = fetch_one(
            """
            SELECT property_id, tenant_id
            FROM LEASE_CONTRACT
            WHERE contract_id = %s AND contract_status = 'Active'
            """,
            (contract_id,),
        )
        if not contract:
            flash("Hợp đồng không còn hiệu lực hoặc không tồn tại. Hãy tải lại trang.", "error")
            contracts = get_active_contract_options()
            return render_template("maintenance_form.html", contracts=contracts)

        execute_insert(
            """
            INSERT INTO MAINTENANCE_REQUEST
                (property_id, tenant_id, description, estimated_cost)
            VALUES (%s, %s, %s, %s)
            """,
            (contract["property_id"], contract["tenant_id"], description, estimated_cost),
        )
        flash("Đã tạo yêu cầu bảo trì và lưu vào MySQL thành công.", "success")
        return redirect(url_for("maintenance_list"))

    return render_template("maintenance_form.html", contracts=contracts)


@app.errorhandler(MySQLError)
def handle_database_error(error):
    app.logger.exception("MySQL operation failed: %s", error)
    return render_template(
        "error.html",
        title="Không thể kết nối hoặc truy vấn MySQL",
        message="Hãy kiểm tra MySQL Server, tên database, tài khoản và mật khẩu trong file .env.",
    ), 503


@app.errorhandler(404)
def page_not_found(_error):
    return render_template(
        "error.html", title="Không tìm thấy trang", message="Địa chỉ bạn truy cập không tồn tại."
    ), 404


if __name__ == "__main__":
    # Chỉ bật debug khi RUN_MODE=development.
    debug_mode = os.getenv("RUN_MODE", "production").lower() == "development"
    app.run(host="127.0.0.1", port=5000, debug=debug_mode)
