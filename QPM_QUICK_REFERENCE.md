# QPM Queries Quick Reference Guide

Quick guide for running and interpreting QPM (Query Performance Monitoring) queries.

---

## Quick Start

### 1. Run All Queries (All Versions)
```bash
./test-qpm-final.sh
```

### 2. Run Individual Queries

**MariaDB 10:**
```bash
docker exec -i mariadb-10 mysql -uroot -prootpass10 < qpm-queries/slow-queries.sql
docker exec -i mariadb-10 mysql -uroot -prootpass10 < qpm-queries/wait-events.sql
docker exec -i mariadb-10 mysql -uroot -prootpass10 < qpm-queries/blocking-sessions.sql
```

**MariaDB 11:**
```bash
docker exec -i mariadb-11 mariadb -uroot -prootpass11 < qpm-queries/slow-queries.sql
docker exec -i mariadb-11 mariadb -uroot -prootpass11 < qpm-queries/wait-events.sql
docker exec -i mariadb-11 mariadb -uroot -prootpass11 < qpm-queries/blocking-sessions.sql
```

**MariaDB 12:**
```bash
docker exec -i mariadb-12 mariadb -uroot -prootpass12 < qpm-queries/slow-queries.sql
docker exec -i mariadb-12 mariadb -uroot -prootpass12 < qpm-queries/wait-events.sql
docker exec -i mariadb-12 mariadb -uroot -prootpass12 < qpm-queries/blocking-sessions.sql
```

---

## Query Outputs Explained

### Slow Queries Output

| Column | Description | Action If High |
|--------|-------------|----------------|
| `query_id` | Unique query digest hash | Use to track specific query |
| `query_text` | Normalized query text | Review for optimization |
| `avg_elapsed_time_ms` | **Average execution time** | >1000ms: Investigate |
| `avg_disk_reads` | Rows examined per execution | High value: Add indexes |
| `avg_disk_writes` | Rows modified per execution | - |
| `has_full_table_scan` | 'Yes' if no index used | 'Yes': Consider adding index |
| `execution_count` | Times query executed | High + slow: Priority fix |
| `last_execution_timestamp` | Last seen time | Check if recent |

**Priority Actions:**
1. `has_full_table_scan='Yes'` + high `execution_count` → Add index
2. `avg_elapsed_time_ms > 1000` → Optimize query
3. `avg_disk_reads` very high → Review query logic

---

### Wait Events Output

| Column | Description | Action Required |
|--------|-------------|-----------------|
| `query_id` | Associated query | - |
| `wait_event_name` | Specific wait event | Identify wait source |
| `wait_category` | Wait type category | See categories below |
| `total_wait_time_ms` | **Total wait time** | >5000ms: Investigate |
| `wait_event_count` | Number of waits | - |
| `avg_wait_time_ms` | Average per wait | - |
| `query_text` | Query causing wait | Review query |

**Wait Categories:**

| Category | Meaning | Common Causes | Action |
|----------|---------|---------------|--------|
| **InnoDB File IO** | Disk operations | Slow disk, large reads | Check disk I/O, add RAM |
| **SQL File IO** | General file ops | Log writes, temp files | Optimize temp space |
| **Network IO** | Network waits | Slow network | Check network latency |
| **Mutex** | Lock contention | High concurrency | Review transaction design |
| **Table Lock** | Table-level locks | Long transactions | Break into smaller txns |
| **Metadata Lock** | DDL blocking | Schema changes | Coordinate DDL |
| **Transaction Lock** | Row-level locks | See Blocking Sessions | - |

---

### Blocking Sessions Output

| Column | Description | Action |
|--------|-------------|--------|
| `blocked_txn_id` | Blocked transaction ID | - |
| `blocked_thread_id` | Blocked thread/connection | Use to kill if needed |
| `blocked_query` | **Query being blocked** | Review transaction |
| `blocking_txn_id` | Blocking transaction ID | - |
| `blocking_thread_id` | Blocker connection | **Kill this to unblock** |
| `blocking_query` | Query holding lock | Review this query |
| `blocked_query_time_ms` | **How long blocked** | >30000ms: Take action |
| `blocking_query_time_ms` | How long blocker ran | - |
| `database_name` | Database affected | - |

**Resolution Steps:**
1. If `blocked_query_time_ms > 60000` (1 min): Immediate action needed
2. Review `blocking_query` - is it stuck?
3. Option 1: Wait for blocker to complete
4. Option 2: Kill blocking session:
   ```sql
   KILL <blocking_thread_id>;
   ```

---

## Common Scenarios

### Scenario 1: Application Slowdown

**Check slow queries:**
```bash
docker exec -i mariadb-10 mysql -uroot -prootpass10 < qpm-queries/slow-queries.sql | head -20
```

**Look for:**
- Queries with `avg_elapsed_time_ms > 1000`
- Queries with `has_full_table_scan = 'Yes'`
- High `execution_count` with slow time

**Action:**
```sql
-- Add index for slow query
CREATE INDEX idx_column_name ON table_name(column_name);

-- Or rewrite query for better performance
```

---

### Scenario 2: High CPU Usage

**Check wait events:**
```bash
docker exec -i mariadb-10 mysql -uroot -prootpass10 < qpm-queries/wait-events.sql
```

**Look for:**
- High `total_wait_time_ms` in **Mutex** category
- Many wait events with category **InnoDB File IO**

**Action:**
- Mutex waits → Reduce concurrent connections
- File IO waits → Check disk performance, increase buffer pool

---

### Scenario 3: Queries Hanging

**Check blocking sessions:**
```bash
docker exec -i mariadb-10 mysql -uroot -prootpass10 < qpm-queries/blocking-sessions.sql
```

**Look for:**
- Any rows returned (means blocking exists)
- `blocked_query_time_ms` values

**Action:**
```sql
-- Connect to database
docker exec -it mariadb-10 mysql -uroot -prootpass10

-- Kill blocking session
KILL <blocking_thread_id>;
```

---

## Filtering and Customization

### Get Only Top 10 Slowest
```sql
-- Add to end of slow-queries.sql
LIMIT 10;  -- instead of LIMIT 100
```

### Filter by Database
```sql
-- Add WHERE clause
WHERE SCHEMA_NAME = 'your_database_name'
AND ...
```

### Change Time Window
```sql
-- Change from 1 hour (3600 seconds) to 30 minutes
WHERE CONVERT_TZ(LAST_SEEN, @@session.time_zone, '+00:00') 
  >= UTC_TIMESTAMP() - INTERVAL 1800 SECOND  -- 30 minutes
```

### Filter by Statement Type
```sql
-- Only SELECT statements
WHERE DIGEST_TEXT LIKE 'SELECT%'
```

---

## Integration Examples

### Cron Job (Every 5 Minutes)
```bash
#!/bin/bash
# /etc/cron.d/qpm-collector

*/5 * * * * root docker exec -i mariadb-10 mysql -uroot -prootpass10 < /path/to/qpm-queries/slow-queries.sql > /var/log/qpm/slow-$(date +\%Y\%m\%d-\%H\%M).log 2>&1
```

### Python Script
```python
import subprocess
import json
from datetime import datetime

def collect_slow_queries(version='10'):
    cmd = f'docker exec -i mariadb-{version} mysql -uroot -prootpass{version} --batch < qpm-queries/slow-queries.sql'
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    
    # Parse output and send to monitoring system
    lines = result.stdout.strip().split('\n')
    # Process data...
    
collect_slow_queries('10')
```

### Save to File with Timestamp
```bash
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

docker exec -i mariadb-10 mysql -uroot -prootpass10 --table < qpm-queries/slow-queries.sql \
  > "qpm-reports/slow_queries_${TIMESTAMP}.txt"

docker exec -i mariadb-10 mysql -uroot -prootpass10 --table < qpm-queries/wait-events.sql \
  > "qpm-reports/wait_events_${TIMESTAMP}.txt"

docker exec -i mariadb-10 mysql -uroot -prootpass10 --table < qpm-queries/blocking-sessions.sql \
  > "qpm-reports/blocking_${TIMESTAMP}.txt"
```

---

## Monitoring Checklist

### Daily
- [ ] Check blocking sessions (should be close to 0)
- [ ] Review slow queries > 1 second
- [ ] Check for new full table scans

### Weekly
- [ ] Analyze wait event trends
- [ ] Review top 20 slow queries
- [ ] Check if indexes are being used

### Monthly
- [ ] Review all queries consistently slow
- [ ] Plan query optimization work
- [ ] Update alert thresholds based on trends

---

## Alerts Setup (Recommended)

### Critical Alerts
```
1. Blocking query > 60 seconds
   Action: Immediate investigation

2. Slow query > 5 seconds with high execution count
   Action: Schedule optimization

3. Wait category = 'Table Lock' with total_wait > 10 seconds
   Action: Check transaction design
```

### Warning Alerts
```
1. Full table scan with execution_count > 1000
   Action: Consider adding index

2. avg_elapsed_time gradually increasing
   Action: Monitor for data growth issues

3. Wait events growing steadily
   Action: Check system resources
```

---

## Troubleshooting

### No Data in Slow Queries
```sql
-- Check if performance_schema is ON
SELECT @@performance_schema;

-- Should return 1, if 0:
-- Restart containers: docker-compose restart
```

### No Data in Wait Events
```sql
-- Check if events are being captured
SELECT COUNT(*) FROM performance_schema.events_waits_current;
SELECT COUNT(*) FROM performance_schema.events_waits_history;

-- If 0, wait events might not be happening or history is too small
```

### No Data in Blocking Sessions
```
This is NORMAL if no blocking exists!

To test, create blocking:
1. Terminal 1: docker exec -it mariadb-10 mysql -uroot -prootpass10 < create-blocking-session1.sql
2. Terminal 2: docker exec -it mariadb-10 mysql -uroot -prootpass10 < create-blocking-session2.sql
3. Terminal 3: Run blocking sessions query
```

---

## File Locations

### Query Files
```
qpm-queries/
├── slow-queries.sql         - Slow query monitoring
├── wait-events.sql          - Wait event analysis
└── blocking-sessions.sql    - Blocking detection
```

### Test Scripts
```
generate-qpm-testdata.sql    - Create test data
test-qpm-final.sh            - Complete test with blocking
create-blocking-session1.sql - Manual blocking test (blocker)
create-blocking-session2.sql - Manual blocking test (blocked)
```

### Reports
```
qpm-reports/final/           - Latest comprehensive reports
QPM_VALIDATION_SUMMARY.md    - Complete validation results
QPM_QUICK_REFERENCE.md       - This file
```

---

## Support

- **Full Validation Report:** See `QPM_VALIDATION_SUMMARY.md`
- **Detailed Reports:** See `qpm-reports/final/mariadb_*_complete_*.md`
- **Test Data:** Run `./test-qpm-final.sh` to regenerate

---

**Last Updated:** April 22, 2026  
**Status:** ✅ All queries validated on MariaDB 10, 11, 12
