-- In postgres 'use database wont work'
-- '\c labdb bob' use this to connect user to that database

select * from hr.employees
insert into hr.employees (emp_id,name,salary,dept,email) values (5,'Blait',38000,'Mechanic','blait@gmail.com');

		-- Create a simple role (no login allowed)
		CREATE ROLE analyst;
		
		-- Create a user (role with LOGIN privilege)
		CREATE ROLE alice WITH LOGIN PASSWORD 'SecurePass123!';
		
		-- Shortcut: CREATE USER is same as CREATE ROLE ... WITH LOGIN
		CREATE USER bob WITH PASSWORD 'Pass456!' CREATEDB;
		
		-- Create a role with specific attributes
		CREATE ROLE manager
		    WITH LOGIN
		    PASSWORD 'ManagerPass!'
		    VALID UNTIL '2026-07-30'
		    CONNECTION LIMIT 10;


				
		-- \du  to view role in cmd line
		
		--Group Role
		-- Part 1: The Foundation
		-- First, we create the Group Role (the permission container) and a User (the person who will inherit those permissions).
			-- 1. Create the Group Role (No login allowed)
			CREATE ROLE developer NOLOGIN;
			
			-- 2. Create an actual user to represent a person, we already created alice and bob
			
			-- 3. Add Alice to the Developer Group and bob to analyst group
			GRANT developer TO alice;
			
			grant analyst to bob;

		-- Part 2: Define the "Developer" Workspace
		-- Now we create a specific area (Schema) where the developers are allowed to work.
		-- This prevents them from making a mess in your default public schema
		
			-- 4. Create a dedicated schema
			CREATE SCHEMA dev_sandbox;
			
			-- 5. Give the GROUP the rights, not the user
			GRANT USAGE ON SCHEMA dev_sandbox TO developer_group;
			GRANT CREATE ON SCHEMA dev_sandbox TO developer_group;

SELECT rolname, rolsuper, rolcreatedb, rolcreaterole, rolcanlogin FROM pg_roles;

-- To see list of ROlES:
SELECT 
    rolname AS role_name,
    rolcanlogin AS is_user,      -- True if they can log in (User)
    rolsuper AS is_superuser,    -- True if they have total control
    rolcreaterole AS can_create_roles,
    rolcreatedb as can_create_db
FROM pg_roles
ORDER BY rolcanlogin DESC;

-- If you are using the terminal, backslash commands are the fastest way to see the "Access privileges" column.

-- For Databases: \l (list databases)

-- For Tables: \dp or \z

-- For Schemas: \dn+



-- Granting Table Privileges
--	Lab setup - Create Sample Schema

create database labdb;

-- Create sample schema and tables
CREATE SCHEMA hr;
CREATE SCHEMA sales;


CREATE TABLE hr.employees (
    emp_id    SERIAL PRIMARY KEY,
    name      TEXT NOT NULL,
    salary    NUMERIC(10,2),
    dept      TEXT,
    email     TEXT
);


CREATE TABLE sales.orders (
    order_id  SERIAL PRIMARY KEY,
    product   TEXT,
    amount    NUMERIC(10,2),
    status    TEXT
);


-- Insert sample data
INSERT INTO hr.employees (name, salary, dept, email) VALUES
  ('Alice Smith', 75000, 'Engineering', 'alice@company.com'),
  ('Bob Jones',   60000, 'Marketing',   'bob@company.com'),
  ('Carol White', 90000, 'Engineering', 'carol@company.com');

INSERT INTO sales.orders (product, amount, status) VALUES
  ('Widget A', 250.00, 'shipped'),
  ('Widget B', 450.00, 'pending');


-- # Grant SELECT on a Single Table
-- Grant read-only access to a specific table

-- 1. Allow Alice to 'see' the hr schema
GRANT USAGE ON SCHEMA hr TO alice;
-- 1. Allow Alice to 'see' the hr schema
GRANT USAGE ON SCHEMA sales TO alice;

GRANT SELECT ON hr.employees TO alice;

-- Grant SELECT on multiple tables at once
GRANT SELECT ON hr.employees, sales.orders TO alice;


-- open new connection with user alice. lets check
-- This should work
SELECT * FROM hr.employees;

select * from sales.orders;


-- This should Fail
INSERT INTO hr.employees (name, salary, dept, email) VALUES
  ('Volt Smith', 75000, 'Engineering', 'volt@company.com')
  
  
-- Allow alice to read and insert but not delete
GRANT SELECT, INSERT ON sales.orders TO alice;



-- 1. Allow bob to 'see' the hr schema
GRANT USAGE ON SCHEMA hr TO bob;
-- 1. Allow bob to 'see' the hr schema
GRANT USAGE ON SCHEMA sales TO bob;

-- Allow bob to read, insert, and update
GRANT SELECT, INSERT, UPDATE ON hr.employees TO bob;

-- Grant ALL privileges on a table
GRANT ALL PRIVILEGES ON hr.employees TO manager;
-- Equivalent shorthand:
GRANT ALL ON hr.employees TO manager;


-- Checking on by one for every role
\c labdb alice
SELECT * FROM sales.orders;                -- Should work
INSERT INTO sales.orders (product,amount,status) VALUES ('Widget C',290,'shipped'); -- Should work
DELETE FROM sales.orders WHERE id = 3;     -- Should FAIL (Permission Denied)


\c labdb bob
select * from hr.employees
insert into hr.employees (emp_id,name,salary,dept,email) values (5,'Blait',38000,'Mechanic','blait@gmail.com');
delete from hr.employees where emp_id = 5; --permision denied
UPDATE hr.employees SET salary = 90000 where emp_id = 5;    -- Should work


\c labdb manager
GRANT USAGE ON SCHEMA hr TO manager;
DELETE FROM hr.employees where emp_id = 5;                  -- Should work (Be careful!)


-- 4.4 Grant on ALL Tables in a Schema
-- Grant SELECT on every existing table in a schema
GRANT SELECT ON ALL TABLES IN SCHEMA hr TO analyst;

-- Grant INSERT on all tables in sales schema
GRANT INSERT ON ALL TABLES IN SCHEMA sales TO alice;

-- Grant all privileges on all tables in schema
GRANT ALL ON ALL TABLES IN SCHEMA hr TO manager;

-- note: 📌 Important
-- GRANT ... ON ALL TABLES only applies to tables that exist at the time of the statement. New tables 
-- created later will NOT automatically inherit these privileges. Use ALTER DEFAULT PRIVILEGES (Section 9) to handle future objects.


-- Grant usage on auto-generated sequence (needed for SERIAL columns)
GRANT USAGE, SELECT ON SEQUENCE hr.employees_emp_id_seq TO alice;
GRANT SELECT, INSERT ON hr.employees TO alice;

-- Grant on ALL sequences in a schema
GRANT USAGE ON ALL SEQUENCES IN SCHEMA hr TO analyst;


-- example
\c labdb alice
-- to see Access privileges
\dp hr.employees

select * from hr.employees;
insert into hr.employees (name,salary,dept,email) values ('mike',38000,'Mechanic','mars@gmail.com');  -- can insert
delete from hr.employees where emp_id = 3; -- denied



--# 5. Column-Level Privileges
-- PostgreSQL allows granting SELECT, INSERT, UPDATE, and REFERENCES at the column level,
-- giving you fine-grained control over which columns a role can access.

	-- 5.1 Syntax for Column Privileges
	GRANT privilege (column_name [, ...]) ON table_name TO role;
	
	-- 5.2 Practical Examples
	-- Allow alice to see only name and dept (not salary or email)
	
	-- 1. Take away the "Master Key" (Table-level access)
	REVOKE SELECT ON hr.employees FROM alice;
	
	-- 2. Hand back the "Small Key" (Column-level access)
	GRANT SELECT (name, dept) ON hr.employees TO alice;
	
	-- Allow bob to update only status column in orders
		-- Step 1: Strip all existing powers from Bob on this table
		REVOKE ALL PRIVILEGES ON sales.orders FROM bob;
		
		-- Step 2: Ensure Bob can see the schema (if not already done)
		GRANT USAGE ON SCHEMA sales TO bob;
		
		-- Step 3: Give Bob SELECT access (so he can find the rows)
		GRANT SELECT ON sales.orders TO bob;
		
		-- Step 4: Give Bob UPDATE access ONLY for the 'status' column
		GRANT UPDATE (status) ON sales.orders TO bob;
	
	-- Allow inserting only specific columns
	GRANT INSERT (product, amount) ON sales.orders TO alice;
	
			-- Verify column-level access
			-- As alice:
			SELECT name, dept FROM hr.employees;   -- OK
			
			--The reason Alice can still see the salary column is a core rule of PostgreSQL permissions: Grants are additive.
			
			SELECT salary FROM hr.employees;        -- ERROR: permission denied for column

		-- switch to bob in cmd: docker exec -it my-postgres psql -U bob -d labdb
		
		select * from sales.orders
		
		UPDATE sales.orders SET status = 'delivered' WHERE order_id = 1;	-- Output: UPDATE 1 (This works!)
		
		UPDATE sales.orders SET amount = 0.00 WHERE order_id = 1; 	-- Output: ERROR: permission denied for column amount of relation orders
		
		/*
		 How to verify this in the "Truth Table" (\dp)
		' \dp sales.orders '
		When you check the privileges now, you will see a slightly more complex output because of the specific column grant. */


-- # 6. Schema and Database Privileges
	-- 6.1 Schema Privileges
	-- Even if a role has SELECT on a table, they also need USAGE on the schema containing that table to be able to access it. 
	-- Schema privileges act as a gateway.
	
					-- First revoke:
/* 
					   Step 1: Revoke access to all CURRENT tables 
					   This removes SELECT, INSERT, UPDATE, DELETE, etc.
					*/
					REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA hr FROM manager;
					REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA sales FROM manager;
					
					/* 
					   Step 2: Revoke access to the SCHEMAS 
					   This prevents the manager from even 'looking' inside the folders.
					*/
					REVOKE ALL PRIVILEGES ON SCHEMA hr FROM manager;
					REVOKE ALL PRIVILEGES ON SCHEMA sales FROM manager;
					
					/* 
					   Step 3: Revoke DEFAULT privileges 
					   This ensures that if you create NEW tables tomorrow, 
					   the manager doesn't automatically get access to them.
					*/
					ALTER DEFAULT PRIVILEGES IN SCHEMA hr REVOKE ALL ON TABLES FROM manager;
					ALTER DEFAULT PRIVILEGES IN SCHEMA sales REVOKE ALL ON TABLES FROM manager;
		
		
				-- Step 1: Grant schema usage (gateway access)
			GRANT USAGE ON SCHEMA hr TO alice;
			GRANT USAGE ON SCHEMA sales TO alice;
			
			-- Step 2: Grant object privileges within schema
			GRANT SELECT ON ALL TABLES IN SCHEMA hr TO alice;
			
			-- Grant CREATE: allows creating objects inside the schema
			GRANT CREATE ON SCHEMA hr TO manager;
			
			-- Grant both
			GRANT USAGE, CREATE ON SCHEMA hr TO developer;
			
				-- example
				CREATE TABLE hr.bank (
		    user_id  SERIAL PRIMARY KEY,
			bank_name varchar(20)
		);
		   -- this table is created after grant select on all table to alice so he cant access it. we need to grant again.
			select * from hr.bank;
			
			drop table hr.bank;
			
		/* Think of Default Privileges as the "Rules for the Future."
		
		Normally, when you run a REVOKE command, it only affects tables that are already sitting in the database. 
		It doesn't change what happens to tables you create tomorrow.
		
		The "Ghost Permission" Problem
		Imagine you are the Superuser, and you once set a rule saying: "From now on, every time I create a table in the hr schema,
		 give the manager full access automatically."
		 Like: */ 	ALTER DEFAULT PRIVILEGES IN SCHEMA hr 
					GRANT SELECT ON TABLES TO manager;
		
		/* You run a normal Revoke: REVOKE ALL ON ALL TABLES IN SCHEMA hr FROM manager;
		
		Result: The manager loses access to all current tables.
		
		Tomorrow, you create a new table: CREATE TABLE hr.salaries (...);
		
		The Problem: Because of that old rule, Postgres automatically grants the manager access to this new table.
		
		The Result: The manager has access again, even though you just revoked everything! */

		
		
	-- 6.2 Database Privileges-- 1. Revoke connect privilege from alice
		
			/*	1. The "PUBLIC" Role Loophole (Most Likely)
				In PostgreSQL, there is a built-in group called PUBLIC. By default, every single user is a member of PUBLIC, 
				and PUBLIC is automatically granted CONNECT and TEMPORARY privileges on every new database.
				
				Even if you revoke the privilege from alice directly, she still has it because she is part of PUBLIC. 
				To fully lock her out, you must revoke it from the group: */
		
				-- Strip the default connection right from everyone
				REVOKE CONNECT ON DATABASE labdb FROM PUBLIC;
				
				-- Now, only people you EXPLICITLY grant will get in
				GRANT CONNECT ON DATABASE labdb TO developer_group;
		
			--  2. Kill all active connections for user 'alice'
				
				SELECT pg_terminate_backend(pid)
				FROM pg_stat_activity
				WHERE usename = 'alice' 
				  AND datname = 'labdb';
				
		
				-- First revoke:
				REVOKE CONNECT ON DATABASE labdb FROM alice;
				
				-- 2. Revoke schema creation privilege from developer
				REVOKE CREATE ON DATABASE labdb FROM developer;
				
				-- 3. Revoke temporary table permission from alice
				REVOKE TEMPORARY ON DATABASE labdb FROM alice;
				
				-- 4. Revoke all database-level privileges from manager
				REVOKE ALL ON DATABASE labdb FROM manager;
		


			-- Grant connect privilege (minimum to connect to database)
			GRANT CONNECT ON DATABASE labdb TO alice;
			
			GRANT CONNECT ON DATABASE labdb TO analyst;
			
			-- Grant ability to create schemas in the database
			GRANT CREATE ON DATABASE labdb TO developer;
			

			
			-- Grant permission to create temporary tables
			GRANT TEMPORARY ON DATABASE labdb TO alice;
			
			-- Grant all database-level privileges
			GRANT ALL ON DATABASE labdb TO manager;
	

	-- 6.3 Function and Procedure Privileges
			--The Function (SECURITY DEFINER) is like a clerk at a window. You ask for something specific, and they go get it for you.
			--Row-Level Security (RLS) is like an invisible filter on the table itself. Everyone looks at the table directly,
			--but they only see the rows they are "allowed" to see.
	
	-- Create a sample function
	CREATE OR REPLACE FUNCTION hr.get_salary(emp TEXT) 
	RETURNS NUMERIC AS $$
	    SELECT salary FROM hr.employees WHERE name = emp;
	$$ LANGUAGE sql 
	SECURITY DEFINER
	SET search_path = hr, pg_temp; -- This locks the function to the HR schema
	
	-- Always specify a search_path for these functions. If you don't, a malicious user could 
	-- create a fake table in a different schema to trick your function into looking at the wrong data.
	
	/* hr.get_salary: This function is stored inside a schema called hr.
	
	(emp TEXT): It takes one input (a string) which represents an employee's name.
	
	RETURNS NUMERIC: It promises to give back a number (the salary).
	
	LANGUAGE sql: This tells PostgreSQL that the function body is written in standard SQL,
	not a procedural language like PL/pgSQL. */
	
	
	-- Remove direct table access
	REVOKE ALL ON hr.employees FROM analyst;
    -- bob is in analyst and alice is in develop group.
	-- 1. Remove her individual "special" access
	REVOKE ALL ON hr.employees FROM alice;
	REVOKE ALL ON SCHEMA hr FROM alice;
	REVOKE ALL ON hr.employees FROM bob;
	REVOKE ALL ON SCHEMA hr FROM bob;
	
	-- Ensure they can still 'see' the schema and 'run' the function
	GRANT USAGE ON SCHEMA hr TO analyst;
	
	-- Grant execute to a role
	GRANT EXECUTE ON FUNCTION hr.get_salary(TEXT) TO analyst;
	
	-- Grant execute on ALL functions in schema
	GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hr TO analyst;
	
	-- Grant execute on ALL procedures in schema
	GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA hr TO manager;
	
	-- SECURITY DEFINER means the function runs with owner's privileges
	-- SECURITY INVOKER (default) runs with caller's privileges
	
	
	-- How to see the "Combined" Reality
	-- it give what privilege role have
	SELECT 
	    grantee, 
	    privilege_type 
	FROM information_schema.role_table_grants 
	WHERE table_name = 'employees' 
	  AND grantee IN ('analyst', 'manager');
	
	-- Checking 
	-- TEST A: Direct Access (Should FAIL)
	-- The analyst should NOT be able to bypass the function
	
	-- TEST A: Direct Access (Should FAIL)
	-- The analyst(bob) should NOT be able to bypass the function

	SELECT * FROM hr.employees;
	
	-- TEST B: Function Access (Should SUCCEED), (name =
	-- 'Bob Jones, baxt Smith, mike)
	-- The analyst uses the function's "elevated" power to see a specific result
	SELECT hr.get_salary('Bob Jones');
	

	
	-- You have mastered the Function (the "Getter"). Now, let's talk about the Procedure (the "Doer").
	
	/*	Function: Designed to calculate and return a value. It's like a calculator. You give it an employee name, and it hands you back a salary.
		You can use a function inside a SELECT statement.
		
		Procedure: Designed to perform a series of actions. It’s like a script or a robot. You tell it to "Process Month-End Bonuses," 
		and it goes through the table updating rows, deleting old logs, 
		and inserting new records. Procedures do not "return" a value in the same way functions do.
	*/

	
	
		-- Let's create a procedure for your hr schema that gives everyone a raise. 
	
			CREATE OR REPLACE PROCEDURE hr.give_raise(percent_increase NUMERIC)
			LANGUAGE plpgsql
			AS $$
			BEGIN
			    -- Perform an action (Update the table)
			    UPDATE hr.employees 
			    SET salary = salary + (salary * percent_increase / 100);
			    
			    -- We can commit the change right here!
			    COMMIT;
			END;
			$$;
			
			-- Phase 1: Revoke all access
			-- 1. Remove all database-level rights
			REVOKE ALL ON DATABASE labdb FROM manager;
			
			-- 2. Remove all schema-level rights
			REVOKE ALL ON SCHEMA hr FROM manager;
			
			-- 3. Remove all table-level rights
			REVOKE ALL ON hr.employees FROM manager;
	
			-- Phase 2: Granting "Power" Access
			-- A manager needs to be able to enter the schema, see the data, and run the procedures (like giving raises).
			
			-- 1. Let them into the house
			GRANT CONNECT ON DATABASE labdb TO manager;
			GRANT USAGE ON SCHEMA hr TO manager;
			
			-- 2. Let them manage the data (Read and Write)
			GRANT SELECT, INSERT, UPDATE, DELETE ON hr.employees TO manager;
			
			-- 3. Let them execute both "Getters" (Functions) and "Doers" (Procedures)
			GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA hr TO manager;
			GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA hr TO manager;
	
			-- Phase 3: Practical Test for the Manager
			-- To verify the manager's access, log in as manager and run this sequence:
	
			-- 1. Check if they can see the sensitive table directly
			SELECT * FROM hr.employees;
			
			-- If you insert new data after calling procedure then salary added by 8000 wont work.
			insert into hr.employees (emp_id, name, salary, dept, email)
			values( 8, 'Surendra', 80000, 'engineer', 'surendra@gmail.com');
			
			-- 2. Check if they can run the "Give Raise" procedure we built earlier
			CALL hr.give_raise(10); 
			
			-- 3. Verify the change was made
			SELECT name, salary FROM hr.employees WHERE name = 'Surendra';
	
	
			-- In a real-world lab, the manager might get annoyed if you create a new table tomorrow and
			-- they can't see it. You can set "Default Privileges" so that the manager automatically gets access to anything created in the future:

			ALTER DEFAULT PRIVILEGES IN SCHEMA hr 
			GRANT SELECT, INSERT, UPDATE ON TABLES TO manager;
			
				-- 1. Check Identity & Global Attributes		
				SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin 
				FROM pg_roles 
				WHERE rolname = 'manager';
				
				-- 2. Check Schema & Table Ownership
				-- If the manager can ALTER DEFAULT PRIVILEGES, they likely own the schema. This query will show you everything the manager "owns."
				SELECT nspname AS schema_name, rolname AS owner 
				FROM pg_namespace n 
				JOIN pg_roles r ON n.nspowner = r.oid 
				WHERE nspname = 'hr';
				
				

			-- Let's verify the "Group Membership"
			-- Run this to see if manager is secretly part of the postgres group:
			
			SELECT 
			    m.rolname AS member, 
			    g.rolname AS group
			FROM pg_auth_members a
			JOIN pg_roles m ON (m.oid = a.member)
			JOIN pg_roles g ON (g.oid = a.roleid)
			WHERE m.rolname = 'manager';



			/*
			 * Since manager is not a superuser, doesn't own the schema, and isn't in a special group, there is only one logical explanation 
			 * for why the ALTER DEFAULT PRIVILEGES command didn't throw an error:
			
			You were setting defaults for the manager's own future actions.
			
			In PostgreSQL, any user can run ALTER DEFAULT PRIVILEGES. However, by default, it only affects objects created by the user who runs the command.
			
			When postgres runs it: They can set defaults for objects created by any role.
			
			When manager runs it: They are essentially telling the database: "In the future, if I create a table in the hr schema, 
			please automatically grant these permissions."
			
			PostgreSQL allows this because you are allowed to decide the default permissions for things you create.
			 */
			
			--Let's prove that the manager is still restricted from seeing the postgres user's work.
			--
			--Switch to the postgres user.
			--
			--Create a new "Secret" table:
			
			CREATE TABLE hr.secret_inventory (item TEXT, quantity INT);
			INSERT INTO hr.secret_inventory VALUES ('Laptops', 50);
			
			drop table hr.secret_inventory;
			
			-- Switch back to the manager user.
			
			SELECT * FROM hr.secret_inventory;
			
		-- SUMMARY:
			--Function vs. Procedure: Functions return values (Calculators); Procedures execute actions with COMMIT (Scripts).
			--
			--Security Definer: Runs with the Creator’s power—allows users to see specific data without table access.
			--
			--Ownership: Owners have "God Mode" over their objects; Permissions are Cumulative (User + Group).

			--Default Privileges: Blueprints for the Future; they only apply to new tables, never existing ones.

