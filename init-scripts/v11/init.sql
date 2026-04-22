-- MariaDB 11 Initialization Script
-- This script runs automatically when the container is first created

USE testdb;

-- Create sample table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Insert sample data
INSERT INTO users (username, email) VALUES 
    ('user1_v11', 'user1@example.com'),
    ('user2_v11', 'user2@example.com'),
    ('user3_v11', 'user3@example.com');

-- Create a stored procedure
DELIMITER //
CREATE PROCEDURE GetUserCount()
BEGIN
    SELECT COUNT(*) as total_users FROM users;
END//
DELIMITER ;

-- Show MariaDB version
SELECT VERSION() as 'MariaDB Version 11';
