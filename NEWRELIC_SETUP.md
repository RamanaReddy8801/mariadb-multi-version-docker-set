# New Relic Setup Guide for MariaDB Docker Containers

## Architecture

New Relic monitoring uses a **single agent container** that monitors all three MariaDB
instances. The agent runs the official `newrelic/infrastructure-bundle` image (which
includes `nri-mysql`) and connects to each MariaDB container over the shared Docker network.

```
┌──────────────────────────── mariadb-network ───────────────────────────┐
│                                                                         │
│  [mariadb-10]           [mariadb-11]           [mariadb-12]            │
│  port 3306              port 3306              port 3306               │
│       ▲                      ▲                      ▲                  │
│       │ hostname:mariadb-10  │ hostname:mariadb-11  │ hostname:mariadb-12 │
│       └──────────────────────┼──────────────────────┘                  │
│                         [newrelic-agent]                                │
│                   infrastructure-bundle + nri-mysql                    │
│                   (3 integration entries, one per DB)                  │
└─────────────────────────────────────────────────────────────────────────┘
```

**Why this approach:**
- No agent installation inside the MariaDB containers
- Single container to manage, replace binary once instead of three times
- Agent container survives MariaDB container recreations
- Follows the official New Relic containerised agent pattern

---

## Prerequisites

- Docker containers running (`mariadb-10`, `mariadb-11`, `mariadb-12`)
- New Relic account with a License Key
- `.env` file configured (see below)

---

## Quick Setup

### Step 1 — Add New Relic credentials to `.env`

```bash
NEW_RELIC_LICENSE_KEY=your_license_key_here
NEWRELIC_DB_USER=newrelic
NEWRELIC_DB_PASSWORD=your_monitor_password_here
```

All three are required. The script and docker-compose both fail immediately if any are missing.

### Step 2 — Create the monitoring user in each MariaDB container

```bash
# All three containers at once
./setup-newrelic.sh

# Or one at a time (useful for testing)
./setup-newrelic.sh mariadb-10
./setup-newrelic.sh mariadb-11
./setup-newrelic.sh mariadb-12
```

This creates `'newrelic'@'%'` in each database with `REPLICATION CLIENT` and `SELECT`
grants so the agent container can connect over the Docker network.

### Step 3 — Start the New Relic agent container

```bash
# Start agent container only (if MariaDB containers are already running)
docker-compose up -d newrelic-agent

# Or start everything together from scratch
docker-compose up -d
```

The agent container waits for all three MariaDB containers to be healthy before starting
(`depends_on: condition: service_healthy`).

### Step 4 — Verify

```bash
# Check agent container is running
docker ps | grep newrelic-agent

# Check agent logs for any errors
docker logs newrelic-agent -f
```

Data appears in New Relic UI after ~2 minutes:
- **Infrastructure > Hosts** — look for `mariadb-monitor`
- **Infrastructure > Integrations > MySQL** — per-database metrics (one entry per MariaDB version)

---

## How it works

### Agent image

`newrelic/infrastructure-bundle:latest` — the official New Relic image that bundles
the infrastructure agent plus all on-host integrations including `nri-mysql`.
No custom Dockerfile needed.

### Integration config

`entrypoint.sh` generates `/etc/newrelic-infra/integrations.d/mysql-config.yml` at
container startup with three `nri-mysql` entries — one per MariaDB version. Credentials
are substituted from the container's environment variables at write time.

The host-side reference config lives at:
```
newrelic-config/mysql-config.yml   (all three entries, reference only)
newrelic-config/entrypoint.sh      (generates the config and starts the agent)
```

### Credentials flow

```
.env
 ├── NEW_RELIC_LICENSE_KEY  → NRIA_LICENSE_KEY env var in agent container
 ├── NEWRELIC_DB_USER       → NEWRELIC_DB_USER env var → substituted in mysql-config.yml
 └── NEWRELIC_DB_PASSWORD   → NEWRELIC_DB_PASSWORD env var → substituted in mysql-config.yml
```

---

## Manual setup (without the script)

### Create monitoring user

```bash
source load-env.sh

# MariaDB 10
docker exec mariadb-10 mysql -uroot -p${MARIADB_10_ROOT_PASSWORD} -e "
  CREATE USER IF NOT EXISTS '${NEWRELIC_DB_USER}'@'%' IDENTIFIED BY '${NEWRELIC_DB_PASSWORD}';
  GRANT REPLICATION CLIENT ON *.* TO '${NEWRELIC_DB_USER}'@'%';
  GRANT SELECT ON *.* TO '${NEWRELIC_DB_USER}'@'%';
  GRANT PROCESS ON *.* TO '${NEWRELIC_DB_USER}'@'%';
  FLUSH PRIVILEGES;
"

# MariaDB 11
docker exec mariadb-11 mariadb -uroot -p${MARIADB_11_ROOT_PASSWORD} -e "
  CREATE USER IF NOT EXISTS '${NEWRELIC_DB_USER}'@'%' IDENTIFIED BY '${NEWRELIC_DB_PASSWORD}';
  GRANT REPLICATION CLIENT ON *.* TO '${NEWRELIC_DB_USER}'@'%';
  GRANT SELECT ON *.* TO '${NEWRELIC_DB_USER}'@'%';
  GRANT PROCESS ON *.* TO '${NEWRELIC_DB_USER}'@'%';
  FLUSH PRIVILEGES;
"

# MariaDB 12
docker exec mariadb-12 mariadb -uroot -p${MARIADB_12_ROOT_PASSWORD} -e "
  CREATE USER IF NOT EXISTS '${NEWRELIC_DB_USER}'@'%' IDENTIFIED BY '${NEWRELIC_DB_PASSWORD}';
  GRANT REPLICATION CLIENT ON *.* TO '${NEWRELIC_DB_USER}'@'%';
  GRANT SELECT ON *.* TO '${NEWRELIC_DB_USER}'@'%';
  GRANT PROCESS ON *.* TO '${NEWRELIC_DB_USER}'@'%';
  FLUSH PRIVILEGES;
"
```

> **Note:** The user is created with `'%'` (any host), not `'localhost'`, because the
> agent connects from a separate container on the Docker network, not from inside
> the MariaDB container itself.

### Start agent container

```bash
docker-compose up -d newrelic-agent
```

---

## Replacing the nri-mysql binary with a custom build

The `nri-mysql` binary inside the agent container lives at:
```
/var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql
```

```bash
# Build for Linux (if on Mac)
GOOS=linux GOARCH=amd64 go build -o nri-mysql ./cmd/nri-mysql

# Replace in the single agent container
docker exec newrelic-agent rm /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql
docker cp /path/to/your/nri-mysql newrelic-agent:/var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql
docker exec newrelic-agent chmod +x /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql
docker exec newrelic-agent /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql -show_version
```

> Binary must be compiled for Linux (`GOOS=linux GOARCH=amd64`), not macOS.

---

## Troubleshooting

### Agent container not starting

```bash
docker logs newrelic-agent
```

Common causes:
- `NEW_RELIC_LICENSE_KEY` missing from `.env`
- One or more MariaDB containers not healthy yet — agent waits for all three to pass `service_healthy`

### Integration not sending data

```bash
# Check agent logs for integration errors
docker logs newrelic-agent | grep -i error

# Verify the monitoring user exists with correct host on each MariaDB container
source load-env.sh
docker exec mariadb-10 mysql -uroot -p${MARIADB_10_ROOT_PASSWORD} -e "
  SELECT user, host FROM mysql.user WHERE user='${NEWRELIC_DB_USER}';
"
# Should show host='%', not host='localhost'
```

### Test the nri-mysql connection manually

```bash
source load-env.sh
docker exec newrelic-agent /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql \
  -hostname mariadb-10 \
  -port 3306 \
  -username ${NEWRELIC_DB_USER} \
  -password ${NEWRELIC_DB_PASSWORD} \
  -metrics
```

Replace `-hostname mariadb-10` with `mariadb-11` or `mariadb-12` to test other instances.
A successful run returns a JSON payload containing `"event_type":"MysqlSample"`.

### Verify config was generated correctly

```bash
docker exec newrelic-agent cat /etc/newrelic-infra/integrations.d/mysql-config.yml
```

---

## Important Notes

1. **Agent container is separate** from MariaDB containers — recreating MariaDB containers
   with `docker-compose down` does NOT affect `newrelic-agent`.
2. **Re-run `setup-newrelic.sh`** only if the MariaDB containers are recreated and the
   monitoring user is lost (data volumes are wiped with `docker-compose down -v`).
3. **Security**: All credentials are managed via `.env`. Never hardcode or commit credentials.
4. **Metrics interval**: Adjust `interval` in `newrelic-config/mysql-config.yml`
   based on your monitoring needs (default: 30s).
5. **Binary replacement**: The `nri-mysql` binary only needs to be replaced once in
   `newrelic-agent` — it monitors all three MariaDB instances from there.
