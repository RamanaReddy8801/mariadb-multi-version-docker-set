-- Test queries to verify MariaDB version and qpm_test data across all versions

-- 1. Check MariaDB version
SELECT VERSION() AS version;

-- 2. Verify qpm_test tables exist and have data
SELECT 'customers'   AS table_name, COUNT(*) AS row_count FROM customers
UNION ALL
SELECT 'orders',       COUNT(*) FROM orders
UNION ALL
SELECT 'products',     COUNT(*) FROM products
UNION ALL
SELECT 'large_table',  COUNT(*) FROM large_table
UNION ALL
SELECT 'blocking_test', COUNT(*) FROM blocking_test;

-- 3. Quick sanity query (exercises a JOIN)
SELECT c.country, COUNT(o.order_id) AS order_count
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.country
ORDER BY order_count DESC
LIMIT 5;
