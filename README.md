# MariaDB Multi-Version Docker Setup

Run MariaDB versions 10, 11, and 12 simultaneously in Docker for **QPM query testing** and **New Relic monitoring**.

---

## Two Main Components

| Component | What it does |
|---|---|
| **QPM Query Testing** | Test and validate slow query, wait event, and blocking session SQL against all 3 MariaDB versions |
| **New Relic Monitoring** | Ship MariaDB metrics to New Relic using a single infrastructure agent container |

---

## Prerequisites

- Docker + Docker Compose installed
- At least 2GB free disk space
- New Relic account (only for monitoring component)

---

## 1. First-Time Setup

### Configure credentials

```bash
cp .env.example .env
# Edit .env with your passwords and New Relic keys
```

Required variables in `.env`:

```bash
# MariaDB credentials (one set per version)
MARIADB_10_ROOT_PASSWORD=your_root_password
MARIADB_10_DATABASE=testdb
MARIADB_10_USER=testuser
MARIADB_10_PASSWORD=your_password
MARIADB_10_PORT=3310
# ... repeat for MARIADB_11_* and MARIADB_12_*

# New Relic (required only for monitoring)
NEW_RELIC_LICENSE_KEY=your_license_key_here
NEWRELIC_DB_USER=newrelic
NEWRELIC_DB_PASSWORD=your_monitor_password_here
```

### Start all containers

```bash
docker-compose up -d
```

**What happens automatically on first boot:**
- MariaDB 10, 11, 12 containers start on ports 3310, 3311, 3312
- `init.sql` runs per version → creates `testdb` + `users` table
- `qpm-testdata.sql` runs per version → creates `qpm_test` database with 5 tables and ~16,500 rows of test data
- Performance Schema consumers are enabled via `mysql-config/performance-schema.cnf`

### Verify containers are healthy

```bash
docker-compose ps
```

All containers should show `healthy` status.

---

## Component 1: QPM Query Testing

QPM (Query Performance Monitoring) queries read from MariaDB's Performance Schema to surface slow queries, wait events, and blocking sessions.

### QPM queries

| File | What it reports |
|---|---|
| `qpm-queries/slow-queries.sql` | Slowest queries from the last hour with execution stats |
| `qpm-queries/wait-events.sql` | IO, lock, and mutex waits correlated to queries |
| `qpm-queries/blocking-sessions.sql` | Active InnoDB lock conflicts with blocker/blocked query details |

### Use case 1: Run a one-shot QPM test across all versions

Generates blocking load, runs all 3 QPM queries on each container, saves Markdown reports.

```bash
./test-qpm-final.sh
```

Reports saved to `qpm-reports/final/mariadb_{10,11,12}_complete_<timestamp>.md`

### Use case 2: Run QPM queries manually on a single container

```bash
source load-env.sh

# Slow queries
docker exec -i mariadb-10 mysql -uroot -p$MARIADB_10_ROOT_PASSWORD \
  --table < qpm-queries/slow-queries.sql

# Wait events
docker exec -i mariadb-10 mysql -uroot -p$MARIADB_10_ROOT_PASSWORD \
  --table < qpm-queries/wait-events.sql

# Blocking sessions (only returns rows when a block is actively happening)
docker exec -i mariadb-10 mysql -uroot -p$MARIADB_10_ROOT_PASSWORD \
  --table < qpm-queries/blocking-sessions.sql
```

Replace `mariadb-10` / `$MARIADB_10_ROOT_PASSWORD` with `mariadb-11`/`$MARIADB_11_ROOT_PASSWORD` or `mariadb-12`/`$MARIADB_12_ROOT_PASSWORD` for other versions.

### Use case 3: Continuous load for sustained QPM testing

Runs 4 parallel load loops indefinitely until the container stops or you press Ctrl+C.
Use this when testing a custom `nri-mysql` binary or validating QPM data over time.

```bash
# mariadb-10 (default)
./load-continuous.sh

# mariadb-11
./load-continuous.sh mariadb-11 mariadb $MARIADB_11_ROOT_PASSWORD

# mariadb-12
./load-continuous.sh mariadb-12 mariadb $MARIADB_12_ROOT_PASSWORD
```

What each loop generates:

| Loop | Activity | Interval |
|---|---|---|
| slow-query | 8 rotating complex SELECTs, JOINs, full-table scans | every 3s |
| blocking | InnoDB row lock contention (2 blocked sessions) | 90s hold, 5s gap |
| dml | INSERT + UPDATE + DELETE on `orders` and `customers` | every 1s |
| wait-event | Bulk UPDATEs across `large_table` to trigger IO waits | every 4s |

Enable debug output to see SQL errors:
```bash
DEBUG=1 ./load-continuous.sh
```

### Use case 4: Verify MariaDB versions are correct

```bash
./test-all-versions.sh
```

Runs `test-queries.sql` on all 3 containers and checks each is running the expected version.

### Use case 5: Manually simulate a blocking session

Open two terminals and run one script in each:

```bash
# Terminal 1 — becomes the blocker
docker exec -i mariadb-10 mysql -uroot -p$MARIADB_10_ROOT_PASSWORD < create-blocking-session1.sql

# Terminal 2 — becomes blocked
docker exec -i mariadb-10 mysql -uroot -p$MARIADB_10_ROOT_PASSWORD < create-blocking-session2.sql
```

Then run `blocking-sessions.sql` in a third terminal to see the result.

---

## Component 2: New Relic Monitoring

A single `newrelic-agent` container monitors all 3 MariaDB instances and ships metrics to New Relic.

### Use case 1: Full setup from scratch

```bash
# Step 1 — ensure NEW_RELIC_LICENSE_KEY, NEWRELIC_DB_USER, NEWRELIC_DB_PASSWORD are in .env

# Step 2 — create monitoring user in each MariaDB container
./setup-newrelic.sh

# Step 3 — start the agent (or use docker-compose up -d to start everything)
docker-compose up -d newrelic-agent
```

The agent waits for all 3 MariaDB containers to be healthy before starting.

### Use case 2: Verify the agent is running and collecting

```bash
# Check container status
docker ps | grep newrelic-agent

# View live agent logs
docker logs newrelic-agent -f

# Verify generated integration config (should show 3 nri-mysql entries)
docker exec newrelic-agent cat /etc/newrelic-infra/integrations.d/mysql-config.yml
```

### Use case 3: Test nri-mysql manually

```bash
source load-env.sh

docker exec newrelic-agent /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql \
  -hostname mariadb-10 \
  -port 3306 \
  -username $NEWRELIC_DB_USER \
  -password $NEWRELIC_DB_PASSWORD \
  -metrics \
  -enable_query_monitoring \
  -pretty
```

Replace `-hostname mariadb-10` with `mariadb-11` or `mariadb-12` to test other instances.

### Use case 4: Replace nri-mysql binary with a custom build

```bash
# Build for Linux (required if building on Mac)
GOOS=linux GOARCH=amd64 go build -o nri-mysql ./cmd/nri-mysql

# Replace binary in agent container
docker exec newrelic-agent rm /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql
docker cp /path/to/your/nri-mysql newrelic-agent:/var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql
docker exec newrelic-agent chmod +x /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql

# Verify
docker exec newrelic-agent /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql -show_version
```

The binary monitors all 3 MariaDB instances — only one replacement needed.

### New Relic UI

- **Infrastructure > Hosts** — look for `mariadb-monitor`
- **Infrastructure > Integrations > MySQL** — per-database metrics (one entry per version)

For full setup documentation see [NEWRELIC_SETUP.md](NEWRELIC_SETUP.md).
For quick commands and troubleshooting see [NEWRELIC_QUICKREF.md](NEWRELIC_QUICKREF.md).

---

## File Structure

```
mariadb-docker-setup/
│
├── docker-compose.yml               # All containers: mariadb-10/11/12 + newrelic-agent
├── .env                             # Credentials (git-ignored)
├── .env.example                     # Template — copy to .env
├── load-env.sh                      # Exports .env variables into shell
│
├── init-scripts/                    # Run automatically on container first boot
│   ├── v10/
│   │   ├── init.sql                 # Creates testdb + users table
│   │   └── qpm-testdata.sql         # Creates qpm_test + test data
│   ├── v11/  (same structure)
│   └── v12/  (same structure)
│
├── mysql-config/
│   └── performance-schema.cnf       # Enables Performance Schema consumers (mounted into all MariaDB containers)
│
├── qpm-queries/                     # The QPM SQL queries being tested
│   ├── slow-queries.sql
│   ├── wait-events.sql
│   └── blocking-sessions.sql
│
├── qpm-reports/
│   └── final/                       # Test reports generated by test-qpm-final.sh
│
├── newrelic-config/
│   ├── entrypoint.sh                # Generates mysql-config.yml at startup + starts agent
│   └── mysql-config.yml             # Reference config (all 3 integration entries)
│
├── load-continuous.sh               # Continuous load generator (runs until stopped)
├── test-qpm-final.sh                # One-shot QPM test across all versions → reports
├── test-all-versions.sh             # Verifies containers run correct MariaDB versions
├── setup-newrelic.sh                # Creates monitoring user in each MariaDB container
├── create-blocking-session1.sql     # Manual blocker session (run in terminal 1)
├── create-blocking-session2.sql     # Manual blocked session (run in terminal 2)
└── test-queries.sql                 # Sample queries for test-all-versions.sh
```

---

## Common Commands

### Container management

```bash
docker-compose up -d                  # Start all containers
docker-compose down                   # Stop and remove containers (keeps data)
docker-compose down -v                # Stop, remove containers AND delete all data
docker-compose ps                     # Check status of all containers
docker-compose restart mariadb-10     # Restart a specific container
docker-compose logs -f mariadb-10     # View logs for a specific container
```

### Connect to a MariaDB container

```bash
source load-env.sh

docker exec -it mariadb-10 mysql -uroot -p$MARIADB_10_ROOT_PASSWORD testdb
docker exec -it mariadb-11 mariadb -uroot -p$MARIADB_11_ROOT_PASSWORD testdb
docker exec -it mariadb-12 mariadb -uroot -p$MARIADB_12_ROOT_PASSWORD testdb
```

### Reset a single version (wipes data and reinitialises)

```bash
docker-compose stop mariadb-10
docker volume rm mariadb-docker-setup_mariadb_10_data
docker-compose up -d mariadb-10
```

---

## Troubleshooting

### Container won't start
```bash
docker-compose logs mariadb-10
lsof -i :3310   # check if port is already in use
```

### QPM queries return empty results
- Confirm Performance Schema is enabled: `docker exec mariadb-10 mysql -uroot -p$MARIADB_10_ROOT_PASSWORD -e "SHOW VARIABLES LIKE 'performance_schema';"`
- Run `load-continuous.sh` first to generate activity, then re-run the queries
- `blocking-sessions.sql` only returns rows when a block is **actively happening**

### New Relic agent not sending data
```bash
docker logs newrelic-agent | grep -i error
docker exec newrelic-agent env | grep NRIA_LICENSE_KEY
```
See [NEWRELIC_QUICKREF.md](NEWRELIC_QUICKREF.md) for full troubleshooting steps.
