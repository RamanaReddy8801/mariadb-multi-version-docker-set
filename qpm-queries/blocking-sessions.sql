-- =====================================
-- MariaDB Blocking Sessions QPM Query
-- =====================================
-- Joins: 6
--   innodb_lock_waits      - base: which txn is waiting on which
--   innodb_trx r           - blocked txn details + raw query (trx_query) + wait start time
--   innodb_trx b           - blocking txn details + raw query fallback
--   threads wt             - blocked thread: host, db, state (not in innodb_trx)
--   threads bt             - blocking thread: host, state
--   esh_blocking (history) - blocking thread's last completed SQL text + execution time
--                            (blocking thread is idle/sleeping so no current statement row)
--
-- Removed joins (vs previous version):
--   events_statements_current      - DIGEST_TEXT is always NULL in MariaDB for in-progress
--                                    statements; TIMER_WAIT replaced by trx_wait_started
--   events_statements_summary_by_digest - depended on esc_waiting.DIGEST which was NULL,
--                                         so this join never matched anything

SELECT
    r.trx_id   AS blocked_txn_id,
    r.trx_mysql_thread_id     AS blocked_thread_id,
    wt.PROCESSLIST_ID    AS blocked_pid,
    wt.PROCESSLIST_HOST  AS blocked_host,
    wt.PROCESSLIST_DB    AS database_name,
    wt.PROCESSLIST_STATE  AS blocked_status,
    b.trx_id             AS blocking_txn_id,
    b.trx_mysql_thread_id  AS blocking_thread_id,
    bt.PROCESSLIST_ID     AS blocking_pid,
    bt.PROCESSLIST_HOST   AS blocking_host,
    r.trx_query            AS blocked_query,
    COALESCE(esh_blocking.SQL_TEXT, b.trx_query)   AS blocking_query,
    MD5(COALESCE(r.trx_query, ''))    AS blocked_query_id,
    MD5(COALESCE(esh_blocking.SQL_TEXT, b.trx_query, ''))    AS blocking_query_id,
    bt.PROCESSLIST_STATE     AS blocking_status,
    -- Time the blocked query has been waiting for the lock (from innodb_trx directly)
    ROUND(TIMESTAMPDIFF(MICROSECOND, r.trx_wait_started, NOW()) / 1000, 3)       AS blocked_query_time_ms,
    -- Execution duration of the blocking statement (from performance_schema history)
    ROUND(COALESCE(esh_blocking.TIMER_WAIT, 0) / 1000000000, 3)    AS blocking_query_time_ms,
    DATE_FORMAT(CONVERT_TZ(r.trx_started, @@session.time_zone, '+00:00'), '%Y-%m-%dT%H:%i:%sZ') AS blocked_txn_start_time,
    DATE_FORMAT(CONVERT_TZ(b.trx_started, @@session.time_zone, '+00:00'), '%Y-%m-%dT%H:%i:%sZ') AS blocking_txn_start_time,
    DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%dT%H:%i:%sZ')    AS collection_timestamp
FROM
    information_schema.innodb_lock_waits w
JOIN information_schema.innodb_trx r ON r.trx_id = w.requesting_trx_id
JOIN information_schema.innodb_trx b ON b.trx_id = w.blocking_trx_id
JOIN performance_schema.threads wt ON wt.PROCESSLIST_ID = r.trx_mysql_thread_id
JOIN performance_schema.threads bt ON bt.PROCESSLIST_ID = b.trx_mysql_thread_id
LEFT JOIN (
    SELECT THREAD_ID, SQL_TEXT, TIMER_WAIT,
           ROW_NUMBER() OVER (PARTITION BY THREAD_ID ORDER BY TIMER_END DESC) AS rn
    FROM performance_schema.events_statements_history
) esh_blocking ON esh_blocking.THREAD_ID = bt.THREAD_ID AND esh_blocking.rn = 1
WHERE
    wt.PROCESSLIST_DB IS NOT NULL
    AND wt.PROCESSLIST_DB NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
ORDER BY
    blocked_txn_start_time ASC
LIMIT 50;
