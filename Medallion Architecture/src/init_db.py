import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()

DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SQL_DIR = os.path.join(BASE_DIR, "sql")

engine = create_engine(f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}")

def execute_sql_file(file_name):
    file_path = os.path.join(SQL_DIR, file_name)
    with open(file_path, 'r') as f:
        sql = f.read()
    
    with engine.begin() as conn:
        conn.execute(text(sql))
    print(f"✅ Executed {file_name}")

def main():
    print("🔄 Initializing database tables...")
    execute_sql_file("01_create_schemas.sql")
    execute_sql_file("02_create_bronze_tables.sql")
    execute_sql_file("03_create_silver_tables.sql")
    execute_sql_file("04_create_gold_tables.sql")
    print("🎉 Database initialized successfully!")

if __name__ == "__main__":
    main()
