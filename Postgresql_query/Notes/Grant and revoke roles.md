# Roles 

This is a specialized guide for **PostgreSQL User & Permission Management**. 
You can add this to your previous Docker guide to have a complete "Cheat Sheet" 
for managing your database security.

---

# 🔐 PostgreSQL Permission & User Management Guide

Use this guide to manage roles, switch users, and troubleshoot "Permission Denied" errors.

## 1. User & Role Basics

| Goal | SQL Command (Run as Superuser) |
| --- | --- |
| **Create User** | `CREATE ROLE alice WITH LOGIN PASSWORD 'SecurePass123!';` |
| **Update Password** | `ALTER ROLE alice WITH PASSWORD 'NewPass456!';` |
| **Disable Login** | `ALTER ROLE alice NOLOGIN;` |
| **Delete User** | `DROP ROLE alice;` |
| **List All Users** | `\du` |

  ** See Access PRIVILEGES** | `\dp hr.employees` |
---

## 2. The Permission Chain (The 3 Keys)

In Postgres, a user needs **three explicit permissions** to read a table. If any are missing, you will get a `permission denied` error.

### Key 1: Database Access

```sql
GRANT CONNECT ON DATABASE labdb TO alice;

```

### Key 2: Schema Access (The "Room")

```sql
GRANT USAGE ON SCHEMA hr TO alice;

```

### Key 3: Table Access (The "Book")

```sql
GRANT SELECT ON TABLE hr.employees TO alice;
-- To give full access (Read/Write/Delete):
GRANT ALL PRIVILEGES ON TABLE hr.employees TO alice;

```

---

## 3. Switching Users (The "Shift")

### Via Terminal (From Windows)

```bash
# Connect as Alice
docker exec -it my-postgres psql -U alice -d labdb

# Connect as Superuser
docker exec -it my-postgres psql -U postgres -d labdb

```

### Via SQL Prompt (Inside psql)

```sql
-- Switch to postgres
\c labdb postgres

-- Switch to alice
\c labdb alice

```

---

## 4. How to Audit Permissions

Since `\du` only shows account types, use these commands to see who can actually see your data:

| Command | Purpose |
| --- | --- |
| **`\dp hr.employees`** | Shows the **Access Control List** for a specific table. |
| **`SELECT current_user;`** | Confirms exactly which user you are logged in as right now. |

### Reading the `\dp` Code:

If you see `alice=r/postgres`, it means:

* **`r`**: SELECT (Read)
* **`w`**: UPDATE (Write)
* **`a`**: INSERT (Append/Add)
* **`d`**: DELETE

---

## 5. Removing Permissions (The Revoke)

```sql
-- Remove table access
REVOKE ALL PRIVILEGES ON TABLE hr.employees FROM alice;

-- Remove schema access
REVOKE USAGE ON SCHEMA hr FROM alice;

-- Remove everything in one go
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA hr FROM alice;

```

---

## 6. Troubleshooting "Permission Denied"

If Alice can't see the data, run these three checks as `postgres`:

1. **Check Schema:** Does she have `USAGE` on the schema?
2. **Check Table:** Does she have `SELECT` on the table?
3. **Check Prefix:** Is she typing `SELECT * FROM employees;` instead of `SELECT * FROM hr.employees;`? (Always use the schema prefix!)

> **Tip:** In DBeaver, if you don't see your changes, right-click the **Connection** or **Schema** and select **Refresh (F5)** to update the metadata view.

