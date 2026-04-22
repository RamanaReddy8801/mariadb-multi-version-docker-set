-- =====================================
-- Script to Create Blocking Sessions
-- Run this in a SECOND session AFTER running session 1
-- =====================================

-- SESSION 2: Blocked Transaction
-- Run this AFTER session 1 is running

USE qpm_test;

-- Start transaction
START TRANSACTION;

-- Try to update the same row (this will be blocked)
UPDATE blocking_test SET balance = balance + 200 WHERE account_id = 1001;

-- This will wait for session 1 to commit or rollback
SELECT 'SESSION 2: Waiting for lock on account_id 1001...' as status;

-- DO NOT COMMIT YET - this will be blocked
-- You can now run the blocking sessions query in a third session to see the lock wait
