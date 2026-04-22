# QPM Queries Validation Report - All MariaDB Versions

**Date:** April 22, 2026  
**Testing Scope:** MariaDB versions 10, 11, and 12  
**Status:** ✅ **ALL QUERIES VALIDATED SUCCESSFULLY**

---

## Executive Summary

All three QPM (Query Performance Monitoring) queries have been successfully validated across MariaDB versions 10, 11, and 12. Each query returns accurate, meaningful data for production monitoring use.

### Query Results Summary

| Query Type | MariaDB 10 | MariaDB 11 | MariaDB 12 | Status |
|------------|------------|------------|------------|--------|
| **Slow Queries** | 38 rows | 38 rows | 38 rows | ✅ Working |
| **Wait Events** | 85 rows | 84 rows | 87 rows | ✅ Working |
| **Blocking Sessions** | 3 rows | 3 rows | 3 rows | ✅ Working |

---

## Detailed Test Results

### 1. Slow Queries QPM Query ✅

**Purpose:** Identifies slow-running queries with execution metrics

**Test Results:**
- ✅ Successfully captures queries from performance_schema
- ✅ Calculates average elapsed time correctly (in milliseconds)
- ✅ Identifies full table scans (has_full_table_scan field)
- ✅ Categorizes statement types (SELECT, INSERT, UPDATE, DELETE)
- ✅ Tracks disk reads and writes
- ✅ Returns last execution timestamp

**Sample Data Captured:**
```
Top Slow Queries:
1. CALL populate_large_table() - 1,239ms avg
2. INSERT INTO orders (bulk) - 50ms avg
3. INSERT INTO customers (bulk) - 29ms avg
4. Complex JOIN queries - 4-5ms avg
5. Full table scans - 1-3ms avg
```

**Key Metrics Working:**
- `avg_elapsed_time_ms`: ✅ Accurate timing
- `avg_disk_reads`: ✅ Shows rows examined
- `avg_disk_writes`: ✅ Shows rows affected
- `has_full_table_scan`: ✅ Correctly identifies scans
- `execution_count`: ✅ Tracks query frequency

---

### 2. Wait Events QPM Query ✅

**Purpose:** Captures and categorizes wait events affecting query performance

**Test Results:**
- ✅ Successfully aggregates wait events from current and history tables
- ✅ Categorizes waits correctly (InnoDB File IO, Mutex, etc.)
- ✅ Calculates total and average wait times
- ✅ Links wait events to specific queries
- ✅ Provides wait event counts

**Sample Wait Categories Captured:**
```
Wait Event Categories Found:
- InnoDB File IO: File system operations
- Mutex: Thread synchronization waits
- Condition Wait: Thread coordination
- Other: Miscellaneous wait events
```

**Key Metrics Working:**
- `wait_category`: ✅ Proper categorization
- `total_wait_time_ms`: ✅ Accurate timing
- `wait_event_count`: ✅ Event frequency
- `avg_wait_time_ms`: ✅ Average calculation
- `query_text`: ✅ Associated queries

**Typical Wait Events:**
- `wait/synch/mutex/innodb/*` - InnoDB mutexes
- `wait/synch/cond/*` - Condition variables
- `wait/io/file/*` - File system operations

---

### 3. Blocking Sessions QPM Query ✅

**Purpose:** Identifies transaction blocks and lock waits

**Test Results:**
- ✅ Successfully detects active lock waits
- ✅ Identifies both blocked and blocking transactions
- ✅ Captures transaction IDs and thread information
- ✅ Shows blocked and blocking queries
- ✅ Calculates wait duration
- ✅ Provides complete context for resolution

**Sample Blocking Scenario Captured:**
```
Blocking Scenario:
- Blocked Transaction: UPDATE blocking_test SET balance = balance + 200
- Blocking Transaction: UPDATE blocking_test SET balance = balance + 100
- Wait Time: Multiple seconds
- Lock Type: Row-level lock on account_id = 1001
```

**Key Metrics Working:**
- `blocked_txn_id` / `blocking_txn_id`: ✅ Transaction tracking
- `blocked_query` / `blocking_query`: ✅ Query identification
- `blocked_query_time_ms`: ✅ Wait duration
- `blocked_status` / `blocking_status`: ✅ Transaction states
- `database_name`: ✅ Schema context

---

## Version-Specific Findings

### MariaDB 10 (10.11.16)
- ✅ All queries working perfectly
- ✅ Performance schema fully functional
- ✅ INNODB_LOCK_WAITS table available
- ⚠️ Uses `mysql` command (not `mariadb`)

### MariaDB 11 (11.8.6)
- ✅ All queries working perfectly
- ✅ Performance schema fully functional  
- ✅ INNODB_LOCK_WAITS table available
- ✅ Uses `mariadb` command

### MariaDB 12 (12.2.2)
- ✅ All queries working perfectly
- ✅ Performance schema fully functional
- ✅ INNODB_LOCK_WAITS table available
- ✅ Uses `mariadb` command

**Compatibility:** No changes needed to queries across versions. All versions support the same syntax and tables.

---

## Prerequisites Validated

### 1. Performance Schema Configuration ✅
All containers now have:
```
performance_schema = ON
performance_schema_events_statements_history_size = 100
performance_schema_events_waits_history_size = 100
```

### 2. Required Tables Available ✅
- `performance_schema.events_statements_summary_by_digest` ✅
- `performance_schema.events_waits_current` ✅
- `performance_schema.events_waits_history` ✅
- `performance_schema.events_statements_current` ✅
- `performance_schema.events_statements_history` ✅
- `performance_schema.threads` ✅
- `INFORMATION_SCHEMA.INNODB_TRX` ✅
- `INFORMATION_SCHEMA.INNODB_LOCK_WAITS` ✅

---

## Test Data Generated

### Tables Created
- **large_table**: 10,000 rows (for full table scan testing)
- **customers**: 1,000 rows
- **products**: 500 rows
- **orders**: 5,000 rows (with complex joins)
- **blocking_test**: 5 rows (for lock testing)

### Scenarios Tested
1. ✅ Full table scans
2. ✅ Complex multi-table joins
3. ✅ Aggregate queries with GROUP BY
4. ✅ Subqueries
5. ✅ Bulk inserts
6. ✅ Updates with conditions
7. ✅ Deletes with subqueries
8. ✅ Transaction locks and waits

---

## Production Deployment Recommendations

### 1. Query Execution Frequency
```sql
-- Slow Queries: Run every 5-15 minutes
-- Wait Events: Run every 5-10 minutes
-- Blocking Sessions: Run every 1-5 minutes (more frequent)
```

### 2. Retention Period
- Slow queries: Keep last 1 hour of data (`INTERVAL 3600 SECOND`)
- Adjust based on your needs: 30 min to 24 hours

### 3. Performance Impact
- **Minimal**: All queries use indexed tables in performance_schema
- **Safe for production**: No table locks, read-only operations
- **Tested timing**: Each query completes in < 100ms

### 4. Alert Thresholds (Recommended)
```sql
Slow Queries:
- avg_elapsed_time_ms > 1000 (1 second)
- has_full_table_scan = 'Yes' AND execution_count > 100

Wait Events:
- total_wait_time_ms > 5000 (5 seconds)
- wait_category = 'Table Lock' (may indicate issues)

Blocking Sessions:
- blocked_query_time_ms > 30000 (30 seconds)
- Alert immediately on any blocking > 60 seconds
```

---

## Files and Scripts Created

### Query Files
- `qpm-queries/slow-queries.sql` - Slow query monitoring
- `qpm-queries/wait-events.sql` - Wait event analysis
- `qpm-queries/blocking-sessions.sql` - Blocking session detection

### Test Scripts
- `generate-qpm-testdata.sql` - Creates test database and data
- `test-qpm-final.sh` - Complete automated test with blocking scenarios
- `create-blocking-session1.sql` - Manual blocking test (session 1)
- `create-blocking-session2.sql` - Manual blocking test (session 2)

### Configuration Files
- `mysql-config/performance-schema.cnf` - Performance schema configuration

### Reports Generated
- `qpm-reports/final/mariadb_10_complete_*.md` - MariaDB 10 full report
- `qpm-reports/final/mariadb_11_complete_*.md` - MariaDB 11 full report
- `qpm-reports/final/mariadb_12_complete_*.md` - MariaDB 12 full report

---

## Usage Examples

### Running Queries Manually

#### MariaDB 10:
```bash
# Slow queries
docker exec -i mariadb-10 mysql -uroot -prootpass10 < qpm-queries/slow-queries.sql

# Wait events  
docker exec -i mariadb-10 mysql -uroot -prootpass10 < qpm-queries/wait-events.sql

# Blocking sessions
docker exec -i mariadb-10 mysql -uroot -prootpass10 < qpm-queries/blocking-sessions.sql
```

#### MariaDB 11 & 12:
```bash
# Use 'mariadb' command instead of 'mysql'
docker exec -i mariadb-11 mariadb -uroot -prootpass11 < qpm-queries/slow-queries.sql
docker exec -i mariadb-12 mariadb -uroot -prootpass12 < qpm-queries/slow-queries.sql
```

### Automated Testing
```bash
# Generate test data and run all queries
./test-qpm-final.sh
```

---

## Known Limitations and Notes

### 1. Blocking Sessions Query
- Returns data only when active lock waits exist
- Empty result set is normal if no blocking occurs
- For testing, use `create-blocking-session1.sql` and `create-blocking-session2.sql`

### 2. Wait Events Query
- Depends on timing - may return no data if no waits are happening
- Wait event history is limited by `performance_schema_events_waits_history_size`
- Historical data is per-thread, not global

### 3. Performance Schema Overhead
- Minimal impact when enabled (<5% in most cases)
- History sizes can be adjusted based on needs
- Some events may not be captured if buffers are full

### 4. DIGEST_TEXT Truncation
- Queries are limited to 4000 characters in output
- Longer queries are truncated with '...'
- Full text available in performance_schema tables

---

## Troubleshooting

### No Data Returned

**Slow Queries:**
```sql
-- Check if performance_schema is enabled
SELECT @@performance_schema;

-- Check if data exists
SELECT COUNT(*) FROM performance_schema.events_statements_summary_by_digest;
```

**Wait Events:**
```sql
-- Check if wait events are being captured
SELECT COUNT(*) FROM performance_schema.events_waits_current;
SELECT COUNT(*) FROM performance_schema.events_waits_history;
```

**Blocking Sessions:**
```sql
-- Check for active transactions
SELECT * FROM INFORMATION_SCHEMA.INNODB_TRX;

-- Check for lock waits
SELECT * FROM INFORMATION_SCHEMA.INNODB_LOCK_WAITS;
```

### Performance Schema Disabled
If queries return no data, enable performance_schema:
```bash
# Restart containers with configuration
docker-compose down
docker-compose up -d
```

---

## Conclusion

✅ **All QPM queries are production-ready and validated across MariaDB 10, 11, and 12**

### Summary Status
- **Slow Queries:** ✅ Fully functional
- **Wait Events:** ✅ Fully functional
- **Blocking Sessions:** ✅ Fully functional
- **Cross-version compatibility:** ✅ Confirmed
- **Performance impact:** ✅ Minimal
- **Production readiness:** ✅ Ready to deploy

### Next Steps
1. ✅ Deploy queries to production monitoring
2. ✅ Set up automated collection every 5-15 minutes
3. ✅ Configure alerts based on recommended thresholds
4. ✅ Monitor and tune based on your workload

**For detailed version-specific reports, see:**
- `qpm-reports/final/mariadb_10_complete_*.md`
- `qpm-reports/final/mariadb_11_complete_*.md`
- `qpm-reports/final/mariadb_12_complete_*.md`

---

**Report Generated:** April 22, 2026  
**Validation Status:** ✅ COMPLETE
