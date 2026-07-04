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


# ──────────────────────────────────────────────
# 1.1  silver.dim_branch
# ──────────────────────────────────────────────
def build_silver_branches():
    sql = """
    TRUNCATE TABLE silver.dim_branch;

    INSERT INTO silver.dim_branch(branch_id, branch_code, branch_name, city, province)
    SELECT DISTINCT
        branch_id::INTEGER,
        UPPER(TRIM(branch_code)),
        INITCAP(TRIM(branch_name)),
        INITCAP(TRIM(city)),
        INITCAP(TRIM(province))
    FROM bronze.branches_raw
    WHERE branch_id IS NOT NULL;
    """
    execute_sql(sql)
    print("✅ silver.dim_branch built successfully.")


# ──────────────────────────────────────────────
# 1.2  silver.dim_customer
# ──────────────────────────────────────────────
def build_silver_customers():
    sql = """
    TRUNCATE TABLE silver.dim_customer;

    INSERT INTO silver.dim_customer(
        customer_id,
        customer_code,
        full_name,
        gender,
        date_of_birth,
        email,
        phone_number,
        city,
        kyc_status,
        customer_created_at,
        customer_updated_at,
        is_valid_email
    )
    SELECT
        customer_id,
        customer_code,
        full_name,
        gender,
        date_of_birth,
        email,
        phone_number,
        city,
        kyc_status,
        customer_created_at,
        customer_updated_at,
        is_valid_email
    FROM (
        SELECT
            customer_id::INTEGER                                    AS customer_id,
            UPPER(TRIM(customer_code))                              AS customer_code,
            COALESCE(NULLIF(INITCAP(TRIM(full_name)), ''), 'Unknown Customer')
                                                                    AS full_name,
            INITCAP(TRIM(gender))                                   AS gender,
            date_of_birth::DATE                                     AS date_of_birth,
            TRIM(email)                                             AS email,
            TRIM(phone_number)                                      AS phone_number,
            INITCAP(TRIM(city))                                     AS city,

            -- Standardize kyc_status
            CASE LOWER(TRIM(kyc_status))
                WHEN 'verified' THEN 'Verified'
                WHEN 'pending'  THEN 'Pending'
                WHEN 'rejected' THEN 'Rejected'
                ELSE 'Unknown'
            END                                                     AS kyc_status,

            created_at::TIMESTAMP                                   AS customer_created_at,
            updated_at::TIMESTAMP                                   AS customer_updated_at,

            -- is_valid_email flag
            CASE
                WHEN TRIM(email) ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'
                    THEN TRUE
                ELSE FALSE
            END                                                     AS is_valid_email,

            -- Keep latest record per customer_id based on updated_at
            ROW_NUMBER() OVER (
                PARTITION BY customer_id::INTEGER
                ORDER BY updated_at::TIMESTAMP DESC
            )                                                       AS rn

        FROM bronze.customers_raw
        WHERE customer_id IS NOT NULL
    ) sub
    WHERE rn = 1;
    """
    execute_sql(sql)
    print("✅ silver.dim_customer built successfully.")


# ──────────────────────────────────────────────
# 1.3  silver.dim_account
# ──────────────────────────────────────────────
def build_silver_accounts():
    sql = """
    TRUNCATE TABLE silver.dim_account;

    INSERT INTO silver.dim_account(
        account_id,
        account_number,
        customer_id,
        branch_id,
        account_type,
        account_status,
        opened_date,
        current_balance,
        is_negative_balance
    )
    SELECT DISTINCT ON (account_id::INTEGER)
        account_id::INTEGER                                 AS account_id,
        UPPER(TRIM(account_number))                         AS account_number,
        customer_id::INTEGER                                AS customer_id,
        branch_id::INTEGER                                  AS branch_id,

        -- Standardize account_type
        CASE LOWER(TRIM(account_type))
            WHEN 'saving'       THEN 'Savings'
            WHEN 'savings'      THEN 'Savings'
            WHEN 'current'      THEN 'Current'
            WHEN 'fixed deposit' THEN 'Fixed Deposit'
            ELSE 'Unknown'
        END                                                 AS account_type,

        -- Standardize account_status
        CASE LOWER(TRIM(account_status))
            WHEN 'active'   THEN 'Active'
            WHEN 'inactive' THEN 'Inactive'
            WHEN 'closed'   THEN 'Closed'
            WHEN 'dormant'  THEN 'Dormant'
            ELSE 'Unknown'
        END                                                 AS account_status,

        opened_date::DATE                                   AS opened_date,
        current_balance::NUMERIC(18,2)                      AS current_balance,

        -- is_negative_balance flag
        CASE
            WHEN current_balance::NUMERIC(18,2) < 0 THEN TRUE
            ELSE FALSE
        END                                                 AS is_negative_balance

    FROM bronze.accounts_raw
    WHERE account_id IS NOT NULL
    ORDER BY account_id::INTEGER;
    """
    execute_sql(sql)
    print("✅ silver.dim_account built successfully.")


# ──────────────────────────────────────────────
# 1.4  silver.fact_transaction
# ──────────────────────────────────────────────
def build_silver_transactions():
    sql = """
    TRUNCATE TABLE silver.fact_transaction;

    INSERT INTO silver.fact_transaction(
        transaction_id,
        transaction_reference,
        account_id,
        transaction_date,
        transaction_type,
        amount,
        currency,
        channel,
        merchant_name,
        transaction_created_at,
        is_valid_account,
        is_valid_amount,
        is_valid_currency
    )
    SELECT
        transaction_id,
        transaction_reference,
        account_id,
        transaction_date,
        transaction_type,
        amount,
        currency,
        channel,
        merchant_name,
        transaction_created_at,
        is_valid_account,
        is_valid_amount,
        is_valid_currency
    FROM (
        SELECT
            t.transaction_id::INTEGER                           AS transaction_id,
            UPPER(TRIM(t.transaction_reference))                AS transaction_reference,
            t.account_id::INTEGER                               AS account_id,
            t.transaction_date::TIMESTAMP                       AS transaction_date,

            -- Standardize transaction_type
            CASE LOWER(TRIM(t.transaction_type))
                WHEN 'deposit'      THEN 'Deposit'
                WHEN 'withdrawal'   THEN 'Withdrawal'
                WHEN 'transfer'     THEN 'Transfer'
                WHEN 'card payment' THEN 'Card Payment'
                WHEN 'fee'          THEN 'Fee'
                ELSE 'Unknown'
            END                                                 AS transaction_type,

            t.amount::NUMERIC(18,2)                             AS amount,
            UPPER(TRIM(t.currency))                             AS currency,

            -- Standardize channel; replace missing with 'Unknown'
            COALESCE(NULLIF(INITCAP(TRIM(t.channel)), ''), 'Unknown')
                                                                AS channel,

            -- Replace missing merchant_name with 'Unknown'
            COALESCE(NULLIF(TRIM(t.merchant_name), ''), 'Unknown')
                                                                AS merchant_name,

            t.created_at::TIMESTAMP                             AS transaction_created_at,

            -- is_valid_account: does account_id exist in silver.dim_account?
            CASE
                WHEN a.account_id IS NOT NULL THEN TRUE
                ELSE FALSE
            END                                                 AS is_valid_account,

            -- is_valid_amount: amount > 0
            CASE
                WHEN t.amount::NUMERIC(18,2) > 0 THEN TRUE
                ELSE FALSE
            END                                                 AS is_valid_amount,

            -- is_valid_currency: NPR or USD
            CASE
                WHEN UPPER(TRIM(t.currency)) IN ('NPR', 'USD') THEN TRUE
                ELSE FALSE
            END                                                 AS is_valid_currency,

            -- Remove duplicates: keep first occurrence per transaction_id
            ROW_NUMBER() OVER (
                PARTITION BY t.transaction_id::INTEGER
                ORDER BY t.created_at::TIMESTAMP DESC
            )                                                   AS rn

        FROM bronze.transactions_raw t
        LEFT JOIN silver.dim_account a
            ON t.account_id::INTEGER = a.account_id
        WHERE t.transaction_id IS NOT NULL
    ) sub
    WHERE rn = 1;
    """
    execute_sql(sql)
    print("silver.fact_transaction built successfully.")


def main():
    print("Building Silver Layer...")
    build_silver_branches()
    build_silver_customers()
    build_silver_accounts()
    build_silver_transactions()
    print("Silver Layer build complete!")


if __name__ == "__main__":
    main()
