import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()

DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

engine = create_engine(f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}")

def execute_sql(sql):
    with engine.begin() as conn:
        conn.execute(text(sql))


def build_gold_transaction_summary():
    sql = """
    TRUNCATE TABLE gold.daily_transaction_summary;

    INSERT INTO gold.daily_transaction_summary(
        transaction_date,
        branch_name,
        account_type,
        transaction_type,
        transaction_count,
        total_amount,
        average_amount
    )
    SELECT
        ft.transaction_date::DATE AS transaction_date,
        db.branch_name,
        da.account_type,
        ft.transaction_type,
        COUNT(ft.transaction_id) AS transaction_count,
        SUM(ft.amount) AS total_amount,
        AVG(ft.amount) AS average_amount
    FROM silver.fact_transaction ft
    JOIN silver.dim_account da
        ON ft.account_id = da.account_id
    JOIN silver.dim_branch db
        ON da.branch_id = db.branch_id
    WHERE ft.is_valid_account = TRUE
      AND ft.is_valid_amount = TRUE
      AND ft.is_valid_currency = TRUE
      AND ft.transaction_type != 'Unknown'
    GROUP BY
        ft.transaction_date::DATE,
        db.branch_name,
        da.account_type,
        ft.transaction_type;
    """
    execute_sql(sql)
    print("✅ gold.daily_transaction_summary built successfully.")


def build_gold_360():
    sql = """
    TRUNCATE TABLE gold.customer_360;

    INSERT INTO gold.customer_360(
        customer_id,
        customer_code,
        full_name,
        city,
        kyc_status,
        total_accounts,
        active_accounts,
        total_balance,
        total_transactions,
        total_transaction_amount,
        last_transaction_date,
        customer_segment
    )
    SELECT
        c.customer_id,
        c.customer_code,
        c.full_name,
        c.city,
        c.kyc_status,
        COALESCE(a.total_accounts, 0) AS total_accounts,
        COALESCE(a.active_accounts, 0) AS active_accounts,
        COALESCE(a.total_balance, 0.00) AS total_balance,
        COALESCE(t.total_transactions, 0) AS total_transactions,
        COALESCE(t.total_transaction_amount, 0.00) AS total_transaction_amount,
        t.last_transaction_date,
        CASE
            WHEN COALESCE(a.total_balance, 0) >= 300000 THEN 'High Value'
            WHEN COALESCE(a.total_balance, 0) >= 100000 THEN 'Medium Value'
            ELSE 'Regular'
        END AS customer_segment
    FROM silver.dim_customer c
    LEFT JOIN (
        SELECT customer_id,
               COUNT(account_id) AS total_accounts,
               SUM(CASE WHEN account_status = 'Active' THEN 1 ELSE 0 END) AS active_accounts,
               SUM(current_balance) AS total_balance
        FROM silver.dim_account
        GROUP BY customer_id
    ) a ON c.customer_id = a.customer_id
    LEFT JOIN (
        SELECT a.customer_id,
               COUNT(ft.transaction_id) AS total_transactions,
               SUM(ft.amount) AS total_transaction_amount,
               MAX(ft.transaction_date) AS last_transaction_date
        FROM silver.fact_transaction ft
        JOIN silver.dim_account a ON ft.account_id = a.account_id
        WHERE ft.is_valid_account = TRUE
          AND ft.is_valid_amount = TRUE
          AND ft.is_valid_currency = TRUE
        GROUP BY a.customer_id
    ) t ON c.customer_id = t.customer_id;
    """
    execute_sql(sql)
    print("✅ gold.customer_360 built successfully.")


def build_branch_performance_summary():
    sql = """
    TRUNCATE TABLE gold.branch_performance_summary;

    INSERT INTO gold.branch_performance_summary(
        branch_id,
        branch_name,
        city,
        total_customers,
        total_accounts,
        total_balance,
        total_transactions,
        total_transaction_amount
    )
    SELECT
        b.branch_id,
        b.branch_name,
        b.city,
        COALESCE(a.total_customers, 0) AS total_customers,
        COALESCE(a.total_accounts, 0) AS total_accounts,
        COALESCE(a.total_balance, 0.00) AS total_balance,
        COALESCE(t.total_transactions, 0) AS total_transactions,
        COALESCE(t.total_transaction_amount, 0.00) AS total_transaction_amount
    FROM silver.dim_branch b
    LEFT JOIN (
        SELECT branch_id,
               COUNT(DISTINCT customer_id) AS total_customers,
               COUNT(account_id) AS total_accounts,
               SUM(current_balance) AS total_balance
        FROM silver.dim_account
        GROUP BY branch_id
    ) a ON b.branch_id = a.branch_id
    LEFT JOIN (
        SELECT a.branch_id,
               COUNT(ft.transaction_id) AS total_transactions,
               SUM(ft.amount) AS total_transaction_amount
        FROM silver.fact_transaction ft
        JOIN silver.dim_account a ON ft.account_id = a.account_id
        WHERE ft.is_valid_account = TRUE
          AND ft.is_valid_amount = TRUE
          AND ft.is_valid_currency = TRUE
        GROUP BY a.branch_id
    ) t ON b.branch_id = t.branch_id;
    """
    execute_sql(sql)
    print("✅ gold.branch_performance_summary built successfully.")


def main():
    print("🔄 Building Gold Layer...")
    build_gold_transaction_summary()
    build_gold_360()
    build_branch_performance_summary()
    print("🎉 Gold Layer build complete!")


if __name__ == "__main__":
    main()
