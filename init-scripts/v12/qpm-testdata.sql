-- ======================================
-- QPM Test Data Generation Script
-- This script creates test scenarios for:
-- 1. Slow queries
-- 2. Wait events
-- 3. Blocking sessions
-- ======================================

-- Create test database if not exists
CREATE DATABASE IF NOT EXISTS qpm_test;
USE qpm_test;

-- ======================================
-- Drop existing tables if they exist
-- ======================================
DROP TABLE IF EXISTS large_table;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS blocking_test;

-- ======================================
-- Create tables for slow query testing
-- ======================================

-- Large table for full table scan testing
CREATE TABLE large_table (
    id INT AUTO_INCREMENT PRIMARY KEY,
    data1 VARCHAR(255),
    data2 TEXT,
    data3 INT,
    data4 DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_data3 (data3)
) ENGINE=InnoDB;

-- Orders table
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT,
    product_id INT,
    order_date DATETIME,
    amount DECIMAL(10, 2),
    status VARCHAR(50),
    notes TEXT,
    INDEX idx_customer (customer_id),
    INDEX idx_product (product_id),
    INDEX idx_date (order_date)
) ENGINE=InnoDB;

-- Customers table
CREATE TABLE customers (
    customer_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(255),
    city VARCHAR(100),
    country VARCHAR(100),
    registration_date DATE,
    INDEX idx_email (email),
    INDEX idx_location (city, country)
) ENGINE=InnoDB;

-- Products table
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(255),
    category VARCHAR(100),
    price DECIMAL(10, 2),
    stock_quantity INT,
    description TEXT,
    INDEX idx_category (category),
    INDEX idx_price (price)
) ENGINE=InnoDB;

-- Table for blocking session testing
CREATE TABLE blocking_test (
    id INT AUTO_INCREMENT PRIMARY KEY,
    account_id INT NOT NULL,
    balance DECIMAL(10, 2),
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_account (account_id)
) ENGINE=InnoDB;

-- ======================================
-- Insert data into tables
-- ======================================

-- Insert 10,000 rows into large_table
DELIMITER $$
CREATE PROCEDURE IF NOT EXISTS populate_large_table()
BEGIN
    DECLARE i INT DEFAULT 1;
    WHILE i <= 10000 DO
        INSERT INTO large_table (data1, data2, data3, data4)
        VALUES (
            CONCAT('Data_', i),
            REPEAT('Lorem ipsum dolor sit amet, consectetur adipiscing elit. ', 10),
            FLOOR(RAND() * 1000),
            ROUND(RAND() * 10000, 2)
        );
        SET i = i + 1;
    END WHILE;
END$$
DELIMITER ;

CALL populate_large_table();
DROP PROCEDURE IF EXISTS populate_large_table;

-- Insert customers
INSERT INTO customers (first_name, last_name, email, city, country, registration_date)
SELECT 
    CONCAT('FirstName', n) AS first_name,
    CONCAT('LastName', n) AS last_name,
    CONCAT('user', n, '@example.com') AS email,
    ELT(MOD(n, 5) + 1, 'New York', 'London', 'Tokyo', 'Paris', 'Berlin') AS city,
    ELT(MOD(n, 5) + 1, 'USA', 'UK', 'Japan', 'France', 'Germany') AS country,
    DATE_SUB(CURDATE(), INTERVAL FLOOR(RAND() * 365) DAY) AS registration_date
FROM 
    (SELECT @rownum := @rownum + 1 AS n
     FROM information_schema.columns c1, information_schema.columns c2, (SELECT @rownum := 0) r
     LIMIT 1000) numbers;

-- Insert products
INSERT INTO products (product_name, category, price, stock_quantity, description)
SELECT 
    CONCAT('Product_', n) AS product_name,
    ELT(MOD(n, 5) + 1, 'Electronics', 'Clothing', 'Food', 'Books', 'Toys') AS category,
    ROUND(RAND() * 1000 + 10, 2) AS price,
    FLOOR(RAND() * 1000) AS stock_quantity,
    CONCAT('Description for product ', n, '. High quality item with great features.') AS description
FROM 
    (SELECT @rownum := @rownum + 1 AS n
     FROM information_schema.columns c1, information_schema.columns c2, (SELECT @rownum := 0) r
     LIMIT 500) numbers;

-- Insert orders
INSERT INTO orders (customer_id, product_id, order_date, amount, status, notes)
SELECT 
    FLOOR(RAND() * 1000) + 1 AS customer_id,
    FLOOR(RAND() * 500) + 1 AS product_id,
    DATE_SUB(NOW(), INTERVAL FLOOR(RAND() * 90) DAY) AS order_date,
    ROUND(RAND() * 1000 + 20, 2) AS amount,
    ELT(MOD(n, 4) + 1, 'pending', 'processing', 'shipped', 'delivered') AS status,
    CONCAT('Order notes for order number ', n) AS notes
FROM 
    (SELECT @rownum := @rownum + 1 AS n
     FROM information_schema.columns c1, information_schema.columns c2, (SELECT @rownum := 0) r
     LIMIT 5000) numbers;

-- Insert data for blocking test
INSERT INTO blocking_test (account_id, balance)
VALUES 
    (1001, 5000.00),
    (1002, 3000.00),
    (1003, 7500.00),
    (1004, 2000.00),
    (1005, 10000.00);

-- ======================================
-- Generate slow queries to populate performance_schema
-- ======================================

-- Slow query 1: Full table scan on large table
SELECT COUNT(*), AVG(data4) 
FROM large_table 
WHERE data1 LIKE '%Data%';

-- Slow query 2: Complex join without proper indexes
SELECT c.first_name, c.last_name, COUNT(o.order_id) as order_count, SUM(o.amount) as total_spent
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE c.country = 'USA'
GROUP BY c.customer_id, c.first_name, c.last_name
HAVING total_spent > 1000;

-- Slow query 3: Subquery with full table scan
SELECT * FROM orders 
WHERE amount > (SELECT AVG(amount) FROM orders)
ORDER BY order_date DESC;

-- Slow query 4: Multiple joins
SELECT 
    o.order_id,
    c.first_name,
    c.last_name,
    p.product_name,
    o.amount,
    o.status
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id
INNER JOIN products p ON o.product_id = p.product_id
WHERE o.order_date >= DATE_SUB(NOW(), INTERVAL 30 DAY)
ORDER BY o.amount DESC;

-- Slow query 5: Heavy aggregation
SELECT 
    DATE(order_date) as order_day,
    status,
    COUNT(*) as order_count,
    SUM(amount) as daily_revenue,
    AVG(amount) as avg_order_value
FROM orders
GROUP BY DATE(order_date), status
ORDER BY order_day DESC;

-- Slow query 6: Text search (no full-text index)
SELECT * FROM large_table 
WHERE data2 LIKE '%consectetur%' 
ORDER BY created_at DESC 
LIMIT 100;

-- Slow query 7: Complex GROUP BY with HAVING
SELECT 
    p.category,
    COUNT(DISTINCT o.order_id) as order_count,
    COUNT(DISTINCT o.customer_id) as customer_count,
    SUM(o.amount) as total_revenue
FROM products p
INNER JOIN orders o ON p.product_id = o.product_id
GROUP BY p.category
HAVING order_count > 10;

-- Slow query 8: Update with full table scan
UPDATE large_table 
SET data4 = data4 * 1.1 
WHERE data3 < 100;

-- Slow query 9: DELETE with complex condition
DELETE FROM large_table 
WHERE id IN (
    SELECT id FROM (
        SELECT id FROM large_table 
        WHERE data3 > 900 
        LIMIT 10
    ) tmp
);

-- Slow query 10: Self-join
SELECT 
    l1.id, l1.data1, COUNT(l2.id) as related_count
FROM large_table l1
LEFT JOIN large_table l2 ON l1.data3 = l2.data3 AND l1.id != l2.id
WHERE l1.data3 BETWEEN 100 AND 200
GROUP BY l1.id, l1.data1
LIMIT 50;

-- ======================================
-- Summary
-- ======================================
SELECT 'Test data generation completed!' as status;
SELECT COUNT(*) as large_table_rows FROM large_table;
SELECT COUNT(*) as customers_count FROM customers;
SELECT COUNT(*) as products_count FROM products;
SELECT COUNT(*) as orders_count FROM orders;
SELECT COUNT(*) as blocking_test_rows FROM blocking_test;
