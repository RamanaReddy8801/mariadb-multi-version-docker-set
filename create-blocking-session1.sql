-- =====================================
-- Script to Create Blocking Sessions
-- Run this in TWO separate sessions to create blocking
-- =====================================

-- SESSION 1: Blocking Transaction
-- Run this first and keep the connection open

USE qpm_test;

-- Start transaction
START TRANSACTION;

-- Lock a row for update
UPDATE blocking_test SET balance = balance + 100 WHERE account_id = 1001;

-- DO NOT COMMIT YET - keep this session open
-- This will create a lock that session 2 will wait for

SELECT 'SESSION 1: Holding lock on account_id 1001. Do NOT close this session yet!' as status;
