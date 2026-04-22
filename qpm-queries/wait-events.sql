-- =====================================
-- MariaDB Wait Events QPM Query
-- =====================================

WITH
wait_data_aggregated AS (
    SELECT
        w.THREAD_ID,
        w.EVENT_NAME AS wait_event_name,
        SUM(w.TIMER_WAIT) AS total_wait_time,
        COUNT(*) AS wait_event_count
    FROM
        performance_schema.events_waits_current w
    GROUP BY
        w.THREAD_ID,
        w.EVENT_NAME
    UNION ALL
    SELECT
        w.THREAD_ID,
        w.EVENT_NAME AS wait_event_name,
        SUM(w.TIMER_WAIT) AS total_wait_time,
        COUNT(*) AS wait_event_count
    FROM
        performance_schema.events_waits_history w
    GROUP BY
        w.THREAD_ID,
        w.EVENT_NAME
),
schema_data AS (
    SELECT
        s.THREAD_ID,
        s.DIGEST AS query_id,
        s.CURRENT_SCHEMA AS database_name,
        s.DIGEST_TEXT AS query_text
    FROM
        performance_schema.events_statements_current s
    WHERE
        s.CURRENT_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    UNION ALL
    SELECT
        s.THREAD_ID,
        s.DIGEST AS query_id,
        s.CURRENT_SCHEMA AS database_name,
        s.DIGEST_TEXT AS query_text
    FROM
        performance_schema.events_statements_history s
    WHERE
        s.CURRENT_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
),
joined_data AS (
    SELECT
        wda.wait_event_name,
        wda.total_wait_time,
        wda.wait_event_count,
        sd.query_id,
        sd.database_name,
        sd.query_text
    FROM
        wait_data_aggregated wda
    JOIN
        schema_data sd ON wda.THREAD_ID = sd.THREAD_ID
)
SELECT
    jd.query_id,
    jd.database_name,
    jd.wait_event_name,
    CASE
        WHEN jd.wait_event_name LIKE 'wait/io/file/innodb/%' THEN 'InnoDB File IO'
        WHEN jd.wait_event_name LIKE 'wait/io/file/sql/%' THEN 'SQL File IO'
        WHEN jd.wait_event_name LIKE 'wait/io/socket/%' THEN 'Network IO'
        WHEN jd.wait_event_name LIKE 'wait/synch/cond/%' THEN 'Condition Wait'
        WHEN jd.wait_event_name LIKE 'wait/synch/mutex/%' THEN 'Mutex'
        WHEN jd.wait_event_name LIKE 'wait/lock/table/%' THEN 'Table Lock'
        WHEN jd.wait_event_name LIKE 'wait/lock/metadata/%' THEN 'Metadata Lock'
        WHEN jd.wait_event_name LIKE 'wait/lock/transaction/%' THEN 'Transaction Lock'
        ELSE 'Other'
    END AS wait_category,
    ROUND(SUM(jd.total_wait_time) / 1000000000, 3) AS total_wait_time_ms,
    SUM(jd.wait_event_count) AS wait_event_count,
    ROUND(SUM(jd.total_wait_time) / 1000000000 / SUM(jd.wait_event_count), 3) AS avg_wait_time_ms,
    CASE
        WHEN CHAR_LENGTH(jd.query_text) > 4000 THEN CONCAT(LEFT(jd.query_text, 3997), '...')
        ELSE jd.query_text
    END AS query_text,
    DATE_FORMAT(UTC_TIMESTAMP(), '%Y-%m-%dT%H:%i:%sZ') AS collection_timestamp
FROM
    joined_data jd
WHERE jd.query_id IS NOT NULL
GROUP BY
    jd.query_id,
    jd.database_name,
    jd.wait_event_name,
    wait_category,
    jd.query_text
ORDER BY
    total_wait_time_ms DESC
LIMIT 100;
