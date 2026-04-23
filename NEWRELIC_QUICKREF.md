# New Relic Quick Reference

## Quick Setup

```bash
# 1. Add credentials to .env
NEW_RELIC_LICENSE_KEY=your_license_key_here
NEWRELIC_DB_USER=newrelic
NEWRELIC_DB_PASSWORD=your_monitor_password_here

# 2. Create monitoring user in MariaDB containers
./setup-newrelic.sh

# 3. Start the single New Relic agent container
docker-compose up -d newrelic-agent
```

All three `.env` variables are required — both the script and docker-compose exit immediately if any are missing.

---

## Agent Container

| Container | Monitors | Image |
|-----------|----------|-------|
| `newrelic-agent` | `mariadb-10`, `mariadb-11`, `mariadb-12` | `newrelic/infrastructure-bundle:latest` |

The single agent connects to all three MariaDB containers via Docker network hostnames.
The monitoring user must have host `'%'` — not `'localhost'` — to allow cross-container connections.

---

## Quick Commands

### Check agent container is running
```bash
docker ps | grep newrelic-agent
```

### View agent logs
```bash
docker logs newrelic-agent -f
```

### Restart the agent
```bash
docker-compose restart newrelic-agent
```

### Stop agent container only
```bash
docker-compose stop newrelic-agent
```

---

## Test Integration Manually

> Run `source load-env.sh` first to load `$NEWRELIC_DB_USER` and `$NEWRELIC_DB_PASSWORD`.

```bash
source load-env.sh

docker exec newrelic-agent /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql \
  -hostname mariadb-10 \
  -port 3306 \
  -username ${NEWRELIC_DB_USER} \
  -password ${NEWRELIC_DB_PASSWORD} \
  -metrics
```

Replace `-hostname mariadb-10` with `mariadb-11` or `mariadb-12` to test the other instances.

A successful run returns JSON containing `"event_type":"MysqlSample"`.

---

## Verify Monitoring User

```bash
source load-env.sh

# Should show host='%' (not 'localhost')
docker exec mariadb-10 mysql -uroot -p${MARIADB_10_ROOT_PASSWORD} \
  -e "SELECT user, host FROM mysql.user WHERE user='${NEWRELIC_DB_USER}';"
```

---

## Replace nri-mysql Binary with a Local Build

```bash
# Build for Linux (if on Mac)
GOOS=linux GOARCH=amd64 go build -o nri-mysql ./cmd/nri-mysql

# Replace in the single agent container
docker exec newrelic-agent rm /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql
docker cp /path/to/your/nri-mysql newrelic-agent:/var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql
docker exec newrelic-agent chmod +x /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql
docker exec newrelic-agent /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql -show_version
```

---

## Configuration Files

| What | Location |
|------|----------|
| nri-mysql config (host reference) | `newrelic-config/mysql-config.yml` |
| nri-mysql config (inside agent container) | `/etc/newrelic-infra/integrations.d/mysql-config.yml` |
| nri-mysql binary (inside agent container) | `/var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql` |
| entrypoint script | `newrelic-config/entrypoint.sh` |

```bash
# Verify config inside agent container
docker exec newrelic-agent cat /etc/newrelic-infra/integrations.d/mysql-config.yml
```

---

## Troubleshooting

### Agent not starting

```bash
docker logs newrelic-agent
```

Common causes:
- `NEW_RELIC_LICENSE_KEY` not set in `.env`
- One or more MariaDB containers not healthy yet (agent depends on all three passing `service_healthy`)

### No data in New Relic UI

1. Check logs for errors:
   ```bash
   docker logs newrelic-agent | grep -i error
   ```

2. Verify monitoring user has host `'%'` on each MariaDB container:
   ```bash
   source load-env.sh
   docker exec mariadb-10 mysql -uroot -p${MARIADB_10_ROOT_PASSWORD} \
     -e "SELECT user, host FROM mysql.user WHERE user='${NEWRELIC_DB_USER}';"
   ```
   If host is `localhost`, re-run `./setup-newrelic.sh`.

3. Test nri-mysql manually (see above).

4. Verify license key is correct:
   ```bash
   docker exec newrelic-agent env | grep NRIA_LICENSE_KEY
   ```

---

## New Relic UI

- **Infrastructure > Hosts**: Server-level metrics per container
- **Infrastructure > Integrations > MySQL**: Database-specific metrics

---

## Metrics Collected

- Database connections (active, max)
- Query performance (queries/sec, slow queries)
- InnoDB buffer pool (usage, hit ratio)
- Table locks and waits
- Replication status and lag
- Disk I/O and storage usage

---

## Important Notes

⚠️ **Container Recreation**: Recreating MariaDB containers with `docker-compose down -v`
wipes the monitoring user — re-run `./setup-newrelic.sh` afterwards.
The `newrelic-agent` container is unaffected by MariaDB container recreations.

⚠️ **Binary Replacement**: A replaced `nri-mysql` binary lives inside `newrelic-agent`,
not the MariaDB containers. It is lost if `newrelic-agent` is recreated — replace it again after any `docker-compose down`.

🔐 **Security**: All credentials are managed via `.env`. The `.env` file is git-ignored and never committed.
