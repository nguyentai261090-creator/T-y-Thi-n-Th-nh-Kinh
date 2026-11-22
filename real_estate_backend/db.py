import os
from contextlib import closing

import mysql.connector
from mysql.connector import Error


def get_connection():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "127.0.0.1"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "real_estate_ledger"),
        charset="utf8mb4",
        use_unicode=True,
        connection_timeout=5,
    )


def fetch_all(sql, params=()):
    conn = get_connection()
    try:
        with closing(conn.cursor(dictionary=True)) as cursor:
            cursor.execute(sql, params)
            return cursor.fetchall()
    finally:
        conn.close()


def fetch_one(sql, params=()):
    conn = get_connection()
    try:
        with closing(conn.cursor(dictionary=True)) as cursor:
            cursor.execute(sql, params)
            return cursor.fetchone()
    finally:
        conn.close()


def execute_insert(sql, params=()):
    conn = get_connection()
    try:
        with closing(conn.cursor()) as cursor:
            cursor.execute(sql, params)
            new_id = cursor.lastrowid
        conn.commit()
        return new_id
    except Error:
        conn.rollback()
        raise
    finally:
        conn.close()
