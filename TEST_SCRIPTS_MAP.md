# Test Scripts and Documentation Map

This document clarifies which test scripts use which test data and generate which reports.

---

## 📊 Quick Reference Table

| Test Script | Uses Test Data | Generates Reports | Related Documentation |
|------------|----------------|-------------------|----------------------|
| **test-all-versions.sh** | `test-queries.sql` | Console output only | `README.md`, `QUICKSTART.md` |
| **test-qpm-final.sh** ⭐ | `init-scripts/vX/qpm-testdata.sql` (auto-runs on boot) + creates blocking | `qpm-reports/final/mariadb_*_complete_*.md` | `QPM_INDEX.md`, `QPM_QUICK_REFERENCE.md` |
| **setup-newrelic.sh** | No test data | No reports | `NEWRELIC_SETUP.md`, `NEWRELIC_QUICKREF.md` |

---

## 🔍 Detailed Breakdown

### 1. test-all-versions.sh
**Purpose:** Basic MariaDB functionality test across all versions

**Uses:**
- `test-queries.sql` - Simple CRUD operations

**Generates:**
- ❌ No MD files
- ✅ Console output only (shows query execution results)

**Related Documentation:**
- `README.md` - Main project documentation
- `QUICKSTART.md` - Quick setup guide

**Run Command:**
```bash
./test-all-versions.sh
```

**What it Tests:**
- Basic database connectivity
- Simple INSERT, SELECT, UPDATE, DELETE operations
- Schema information queries
- Index usage

---

### 2. test-qpm-final.sh ⭐ **RECOMMENDED**
**Purpose:** Complete QPM test with artificial blocking scenarios

**Uses:**
- `init-scripts/vX/qpm-testdata.sql` - Auto-runs on container first boot; creates `qpm_test` database with 5 tables and ~16,500 rows. No manual data generation needed.
- **PLUS** Creates artificial blocking sessions in background:
  - Session 1: Starts transaction and holds lock
  - Session 2: Tries to update same row (gets blocked)

**Generates:**
- ✅ `qpm-reports/final/mariadb_10_complete_YYYYMMDD_HHMMSS.md`
- ✅ `qpm-reports/final/mariadb_11_complete_YYYYMMDD_HHMMSS.md`
- ✅ `qpm-reports/final/mariadb_12_complete_YYYYMMDD_HHMMSS.md`

**Related Documentation:**
- `QPM_INDEX.md` - Complete project overview
- `QPM_QUICK_REFERENCE.md` - Daily usage guide
- `QPM_VALIDATION_SUMMARY.md` - Validation results

**Run Command:**
```bash
./test-qpm-final.sh
```

**What it Tests:**
- ✅ Slow queries detection (with data)
- ✅ Wait events capture (with data)
- ✅ Blocking sessions (with artificial blocks)

**Current Reports:**
- `qpm-reports/final/mariadb_10_complete_20260422_154526.md` ✅
- `qpm-reports/final/mariadb_11_complete_20260422_154526.md` ✅
- `qpm-reports/final/mariadb_12_complete_20260422_154526.md` ✅

---

### 3. setup-newrelic.sh
**Purpose:** Install and configure New Relic monitoring

**Uses:**
- ❌ No test data
- Installs agents and creates monitoring user

**Generates:**
- ❌ No MD reports
- ✅ Console output with installation status

**Related Documentation:**
- `NEWRELIC_SETUP.md` - Complete installation guide
- `NEWRELIC_QUICKREF.md` - Quick reference for commands

**Run Command:**
```bash
export NEW_RELIC_LICENSE_KEY="your_key_here"
./setup-newrelic.sh
```

---

## 📁 Test Data Files Explained

### test-queries.sql
**Used by:** `test-all-versions.sh`

**Contains:**
- Simple verification queries
- Basic CRUD operations
- Version checking
- Table inspection

**Size:** Small (~1 KB)

**Purpose:** Quick sanity check

---

### init-scripts/vX/qpm-testdata.sql
**Used by:** Docker (auto-runs on container first boot via `/docker-entrypoint-initdb.d`)

**Contains:**
- Database creation: `qpm_test`
- Table creation: 5 tables
- Data insertion: ~16,500 total rows
- Full table scans, complex joins, aggregations

**Size:** Large (generates 16K+ rows)

**Purpose:** Comprehensive QPM testing — runs automatically, no manual step needed

**Tables:**
```
large_table:    10,000 rows (full table scans)
customers:       1,000 rows (joins)
products:          500 rows (joins)
orders:          5,000 rows (complex queries)
blocking_test:       5 rows (lock testing)
```

**Note:** Each version has its own copy: `init-scripts/v10/`, `v11/`, `v12/`. Data is created once on container first start and persists in the named Docker volume. To reset, remove the volume: `docker volume rm mariadb-docker-setup_mariadb_10_data`

---

### create-blocking-session1.sql
**Used by:** Manual testing only (not automatic scripts)

**Contains:**
- Starts transaction
- Updates blocking_test table
- Holds lock (does NOT commit)

**Purpose:** Create blocking transaction manually

**Usage:**
```bash
# Terminal 1 (creates blocker)
docker exec -it mariadb-10 mysql -uroot -prootpass10 < create-blocking-session1.sql
```

---

### create-blocking-session2.sql
**Used by:** Manual testing only (not automatic scripts)

**Contains:**
- Starts transaction
- Tries to update same row
- Gets blocked by session 1

**Purpose:** Create blocked transaction manually

**Usage:**
```bash
# Terminal 2 (gets blocked)
docker exec -it mariadb-10 mysql -uroot -prootpass10 < create-blocking-session2.sql
```

**Note:** `test-qpm-final.sh` creates blocking scenarios automatically, so you don't need these manual scripts unless you want to test manually.

---

## 📚 Documentation Files Explained

### README.md
- Main project documentation
- Covers all MariaDB versions setup
- Connection details
- Basic usage

**Related to:** General project usage

---

### QUICKSTART.md
- Quick setup guide
- Step-by-step instructions
- Basic commands

**Related to:** Initial setup

---

### QPM_INDEX.md ⭐ **START HERE FOR QPM**
- Complete QPM project overview
- Lists all queries, scripts, and reports
- Quick commands
- Navigation guide

**Related to:** All QPM testing

---

### QPM_VALIDATION_SUMMARY.md
- Complete validation report
- Test results for all versions
- Findings and recommendations
- Troubleshooting guide

**Related to:** `test-qpm-final.sh`

---

### QPM_QUICK_REFERENCE.md
- Daily usage guide
- Query output explanations
- Common scenarios
- Filtering examples

**Related to:** Production usage of QPM queries

---

### NEWRELIC_SETUP.md
- Complete New Relic installation guide
- Step-by-step manual setup
- Configuration details
- Troubleshooting

**Related to:** `setup-newrelic.sh`

---

### NEWRELIC_QUICKREF.md
- Quick reference for New Relic
- Common commands
- Monitoring user details
- Quick troubleshooting

**Related to:** `setup-newrelic.sh`

---

## 🎯 Usage Scenarios

### Scenario 1: First Time Setup
```bash
# 1. Start containers
docker-compose up -d

# 2. Run basic test
./test-all-versions.sh

# 3. Read documentation
cat README.md
cat QUICKSTART.md
```

---

### Scenario 2: Test QPM Queries
```bash
# Run complete QPM test with all scenarios
./test-qpm-final.sh

# Read results
cat QPM_INDEX.md
cat qpm-reports/final/mariadb_10_complete_*.md
```

---

### Scenario 3: Daily QPM Monitoring
```bash
# Run individual queries
docker exec -i mariadb-10 mysql -uroot -prootpass10 < qpm-queries/slow-queries.sql

# Reference guide
cat QPM_QUICK_REFERENCE.md
```

---

### Scenario 4: Setup New Relic
```bash
# Set license key
export NEW_RELIC_LICENSE_KEY="your_key"

# Run setup
./setup-newrelic.sh

# Read documentation
cat NEWRELIC_SETUP.md
cat NEWRELIC_QUICKREF.md
```

---

### Scenario 5: Manual Blocking Test
```bash
# Terminal 1
docker exec -it mariadb-10 mysql -uroot -prootpass10 < create-blocking-session1.sql

# Terminal 2
docker exec -it mariadb-10 mysql -uroot -prootpass10 < create-blocking-session2.sql

# Terminal 3
docker exec -i mariadb-10 mysql -uroot -prootpass10 < qpm-queries/blocking-sessions.sql
```

---

## 📊 Report Naming Convention

### QPM Reports
```
qpm-reports/final/mariadb_[VERSION]_complete_[TIMESTAMP].md

Example:
qpm-reports/final/mariadb_10_complete_20260422_154526.md
```

**Generated by:** `test-qpm-final.sh`

**Contains:** All three query results (slow queries, wait events, blocking sessions)

---

## 🔄 Workflow Summary

### For Testing QPM Queries:

```
test-qpm-final.sh
    ↓
Uses: init-scripts/vX/qpm-testdata.sql (auto-runs on container boot)
    +
Creates artificial blocking scenarios
    ↓
Runs: slow-queries.sql, wait-events.sql, blocking-sessions.sql
    ↓
Generates: qpm-reports/final/mariadb_*_complete_*.md
    ↓
Read: QPM_INDEX.md, QPM_VALIDATION_SUMMARY.md, QPM_QUICK_REFERENCE.md
```

### For Basic Testing:

```
test-all-versions.sh
    ↓
Uses: test-queries.sql (simple queries)
    ↓
Output: Console only (no MD files)
    ↓
Read: README.md, QUICKSTART.md
```

### For New Relic:

```
setup-newrelic.sh
    ↓
No test data needed
    ↓
Output: Console installation status
    ↓
Read: NEWRELIC_SETUP.md, NEWRELIC_QUICKREF.md
```

---

## 🎯 Quick Decision Guide

**Q: Which test script should I run?**

| You Want To... | Run This Script | Use This Data |
|----------------|-----------------|---------------|
| Quick check all versions work | `test-all-versions.sh` | `test-queries.sql` |
| **Test QPM queries** ⭐ | `test-qpm-final.sh` | `init-scripts/vX/qpm-testdata.sql` (auto) |
| Setup New Relic monitoring | `setup-newrelic.sh` | None |
| Manual blocking test | Run manually | `create-blocking-session*.sql` |

**Q: Which documentation should I read?**

| You Want To... | Read This |
|----------------|-----------|
| Understand the project | `README.md` |
| Quick setup | `QUICKSTART.md` |
| **Understand QPM testing** ⭐ | `QPM_INDEX.md` |
| See QPM validation results | `QPM_VALIDATION_SUMMARY.md` |
| Daily QPM usage | `QPM_QUICK_REFERENCE.md` |
| Setup New Relic | `NEWRELIC_SETUP.md` |
| New Relic quick ref | `NEWRELIC_QUICKREF.md` |

**Q: Where are my test results?**

| Script | Results Location |
|--------|------------------|
| `test-all-versions.sh` | Console output only |
| **`test-qpm-final.sh`** | **`qpm-reports/final/mariadb_*_complete_*.md`** ⭐ |
| `setup-newrelic.sh` | Console output only |

---

## ✅ Current State

**Active Reports:**
- ✅ `qpm-reports/final/mariadb_10_complete_20260422_154526.md` (50K)
- ✅ `qpm-reports/final/mariadb_11_complete_20260422_154526.md` (50K)
- ✅ `qpm-reports/final/mariadb_12_complete_20260422_154526.md` (50K)

**Generated by:** `test-qpm-final.sh` at 2026-04-22 15:45:26

**Contains:**
- 38 slow queries per version ✅
- 84-87 wait events per version ✅
- 3 blocking sessions per version ✅

---

**Last Updated:** April 22, 2026  
**Status:** All test scripts validated and documented ✅
