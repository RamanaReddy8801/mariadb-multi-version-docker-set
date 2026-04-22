-- Test Queries to verify across all MariaDB versions
-- Run this file against all three versions to ensure compatibility

-- 1. Check MariaDB version
SELECT VERSION() as version;

-- 2. Show all users
SELECT * FROM users ORDER BY id;

-- 3. Count users
SELECT COUNT(*) as total_users FROM users;

-- 4. Insert a new user
INSERT INTO users (username, email) VALUES ('test_user', 'test@example.com');

-- 5. Update a user
UPDATE users SET email = 'updated@example.com' WHERE username = 'test_user';

-- 6. Select with WHERE clause
SELECT * FROM users WHERE username LIKE '%test%';

-- 7. Call stored procedure
CALL GetUserCount();

-- 8. Show table structure
DESCRIBE users;

-- 9. Show indexes
SHOW INDEX FROM users;

-- 10. Delete test user
DELETE FROM users WHERE username = 'test_user';

-- 11. Verify deletion
SELECT COUNT(*) as remaining_users FROM users;
