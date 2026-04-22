-- =====================================
-- MariaDB Slow Queries QPM Query
-- =====================================

SELECT
    DIGEST AS query_id,
    CASE
        WHEN CHAR_LENGTH(DIGEST_TEXT) > 4000 THEN CONCAT(LEFT(DIGEST_TEXT, 3997), '...')
        ELSE DIGEST_TEXT
    END AS query_text,
    SCHEMA_NAME AS database_name,
    'N/A' AS schema_name,
    COUNT_STAR AS execution_count,
    NULL AS avg_cpu_time_ms,
    ROUND((SUM_TIMER_WAIT / COUNT_STAR) / 1000000000, 3) AS avg_elapsed_time_ms,
    SUM_ROWS_EXAMINED / COUNT_STAR AS avg_disk_reads,
    SUM_ROWS_AFFECTED / COUNT_STAR AS avg_disk_writes,
    CASE
        WHEN SUM_NO_INDEX_USED > 0 THEN 'Yes'
        ELSE 'No'
    END AS has_full_table_scan,
    CASE
        WHEN DIGEST_TEXT LIKE 'SELECT%' THEN 'SELECT'
        WHEN DIGEST_TEXT LIKE 'INSERT%' THEN 'INSERT'
        WHEN DIGEST_TEXT LIKE 'UPDATE%' THEN 'UPDATE'
        WHEN DIGEST_TEXT LIKE 'DELETE%' THEN 'DELETE'
        ELSE 'OTHER'
    END AS statement_type,
    DATE_FORMAT(CONVERT_TZ(LAST_SEEN, @@session.time_zone, '+00:00'), '%Y-%m-%dT%H:%i:%sZ') AS last_execution_timestamp,
    DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%dT%H:%i:%sZ') AS collection_timestamp
FROM performance_schema.events_statements_summary_by_digest
WHERE CONVERT_TZ(LAST_SEEN, @@session.time_zone, '+00:00') >= UTC_TIMESTAMP() - INTERVAL 3600 SECOND
    AND SCHEMA_NAME IS NOT NULL
    AND SCHEMA_NAME NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
ORDER BY avg_elapsed_time_ms DESC
LIMIT 100;
