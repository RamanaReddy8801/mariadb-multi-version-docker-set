-- =====================================
-- MariaDB Blocking Sessions QPM Query
-- =====================================

SELECT 
    r.trx_id AS blocked_txn_id,
    r.trx_mysql_thread_id AS blocked_thread_id,
    rt.PROCESSLIST_ID AS blocked_pid,
    rt.PROCESSLIST_HOST AS blocked_host,
    rt.PROCESSLIST_DB AS database_name,
    rt.PROCESSLIST_STATE AS blocked_status,
    b.trx_id AS blocking_txn_id,
    b.trx_mysql_thread_id AS blocking_thread_id,
    bt.PROCESSLIST_ID AS blocking_pid,
    bt.PROCESSLIST_HOST AS blocking_host,
    COALESCE(
        CASE 
            WHEN CHAR_LENGTH(rd.DIGEST_TEXT) > 4000 THEN CONCAT(LEFT(rd.DIGEST_TEXT, 3997), '...')
            ELSE rd.DIGEST_TEXT
        END,
        CASE 
            WHEN CHAR_LENGTH(rdh.DIGEST_TEXT) > 4000 THEN CONCAT(LEFT(rdh.DIGEST_TEXT, 3997), '...')
            ELSE rdh.DIGEST_TEXT
        END,
        r.trx_query
    ) AS blocked_query,
    COALESCE(
        CASE 
            WHEN CHAR_LENGTH(bd.DIGEST_TEXT) > 4000 THEN CONCAT(LEFT(bd.DIGEST_TEXT, 3997), '...')
            ELSE bd.DIGEST_TEXT
        END,
        CASE 
            WHEN CHAR_LENGTH(bdh.DIGEST_TEXT) > 4000 THEN CONCAT(LEFT(bdh.DIGEST_TEXT, 3997), '...')
            ELSE bdh.DIGEST_TEXT
        END,
        b.trx_query,
        'Idle Transaction (No active query)'
    ) AS blocking_query,
    COALESCE(rc.DIGEST, rch.DIGEST) AS blocked_query_id,
    COALESCE(bc.DIGEST, bch.DIGEST) AS blocking_query_id,
    bt.PROCESSLIST_STATE AS blocking_status,
    ROUND((UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(r.trx_started)) * 1000, 3) AS blocked_query_time_ms,
    ROUND((UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(b.trx_started)) * 1000, 3) AS blocking_query_time_ms,
    DATE_FORMAT(r.trx_started, '%Y-%m-%dT%H:%i:%sZ') AS blocked_txn_start_time,
    DATE_FORMAT(b.trx_started, '%Y-%m-%dT%H:%i:%sZ') AS blocking_txn_start_time,
    DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%dT%H:%i:%sZ') AS collection_timestamp
FROM 
    INFORMATION_SCHEMA.INNODB_LOCK_WAITS w
JOIN 
    INFORMATION_SCHEMA.INNODB_TRX r ON r.trx_id = w.requesting_trx_id
JOIN 
    INFORMATION_SCHEMA.INNODB_TRX b ON b.trx_id = w.blocking_trx_id
JOIN 
    performance_schema.threads rt ON rt.PROCESSLIST_ID = r.trx_mysql_thread_id
JOIN 
    performance_schema.threads bt ON bt.PROCESSLIST_ID = b.trx_mysql_thread_id
LEFT JOIN 
    performance_schema.events_statements_current rc ON rc.THREAD_ID = rt.THREAD_ID
LEFT JOIN 
    performance_schema.events_statements_current bc ON bc.THREAD_ID = bt.THREAD_ID
LEFT JOIN 
    performance_schema.events_statements_history rch 
    ON rch.THREAD_ID = rt.THREAD_ID 
    AND rch.EVENT_ID = (
        SELECT MAX(EVENT_ID) 
        FROM performance_schema.events_statements_history 
        WHERE THREAD_ID = rt.THREAD_ID
    )
LEFT JOIN 
    performance_schema.events_statements_history bch 
    ON bch.THREAD_ID = bt.THREAD_ID 
    AND bch.EVENT_ID = (
        SELECT MAX(EVENT_ID) 
        FROM performance_schema.events_statements_history 
        WHERE THREAD_ID = bt.THREAD_ID
    )
LEFT JOIN 
    performance_schema.events_statements_summary_by_digest rd ON rd.DIGEST = rc.DIGEST AND rd.SCHEMA_NAME = rt.PROCESSLIST_DB
LEFT JOIN 
    performance_schema.events_statements_summary_by_digest bd ON bd.DIGEST = bc.DIGEST AND bd.SCHEMA_NAME = bt.PROCESSLIST_DB
LEFT JOIN 
    performance_schema.events_statements_summary_by_digest rdh ON rdh.DIGEST = rch.DIGEST AND rdh.SCHEMA_NAME = rt.PROCESSLIST_DB
LEFT JOIN 
    performance_schema.events_statements_summary_by_digest bdh ON bdh.DIGEST = bch.DIGEST AND bdh.SCHEMA_NAME = bt.PROCESSLIST_DB
WHERE
    rt.PROCESSLIST_DB IS NOT NULL
    AND rt.PROCESSLIST_DB NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
ORDER BY 
    blocked_txn_start_time ASC
LIMIT 50;
