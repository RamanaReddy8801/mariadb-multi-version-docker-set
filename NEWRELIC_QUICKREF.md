# New Relic Quick Reference

## Quick Setup

```bash
# 1. Add credentials to .env
NEW_RELIC_LICENSE_KEY=your_license_key_here
NEWRELIC_DB_USER=newrelic
NEWRELIC_DB_PASSWORD=your_monitor_password_here

# 2. Run automated setup
./setup-newrelic.sh
```

All three variables are required — the script exits immediately if any are missing from `.env`.

## Monitoring User Credentials

Credentials are read from `.env`. The defaults after first setup:

- **Username**: value of `NEWRELIC_DB_USER` in `.env`
- **Password**: value of `NEWRELIC_DB_PASSWORD` in `.env`
- **Permissions**: `REPLICATION CLIENT`, `SELECT` on all databases

## Quick Commands

### Check Agent Status
```bash
docker exec mariadb-10 ps aux | grep newrelic-infra
docker exec mariadb-11 ps aux | grep newrelic-infra
docker exec mariadb-12 ps aux | grep newrelic-infra
```

### View Agent Logs
```bash
docker exec mariadb-10 tail -f /var/log/newrelic-infra/newrelic-infra.log
```

### Test Integration Manually

> Run `source load-env.sh` first to load `$NEWRELIC_DB_USER` and `$NEWRELIC_DB_PASSWORD`.

```bash
docker exec mariadb-10 /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql \
  -hostname localhost \
  -port 3306 \
  -username ${NEWRELIC_DB_USER} \
  -password ${NEWRELIC_DB_PASSWORD} \
  -metrics
```

### Restart Agent
```bash
docker exec mariadb-10 service newrelic-infra restart
```

### Check MySQL User
```bash
source load-env.sh
docker exec mariadb-10 mysql -uroot -p${MARIADB_10_ROOT_PASSWORD} -e "SHOW GRANTS FOR '${NEWRELIC_DB_USER}'@'localhost';"
```

---

## Replace nri-mysql Binary with a Local Build

The apt-installed binary lives at:
```
/var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql
```

Use these commands to swap it out with your own build.

> **Note:** Binary must be compiled for Linux (`GOOS=linux GOARCH=amd64`), not macOS.

```bash
# Build for Linux (if on Mac)
GOOS=linux GOARCH=amd64 go build -o nri-mysql ./cmd/nri-mysql

# Remove the apt-installed binary
docker exec mariadb-10 rm /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql

# Copy your local binary in
docker cp /path/to/your/nri-mysql mariadb-10:/var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql

# Make it executable
docker exec mariadb-10 chmod +x /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql

# Verify
docker exec mariadb-10 /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql --version
```

Repeat for mariadb-11 and mariadb-12 (same commands, swap container name).

---

## Configuration Files

| File | Location inside container |
|------|--------------------------|
| Agent Config | `/etc/newrelic-infra.yml` |
| MySQL Integration | `/etc/newrelic-infra/integrations.d/mysql-config.yml` |
| Agent Logs | `/var/log/newrelic-infra/newrelic-infra.log` |
| nri-mysql Binary | `/var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql` |

## Container Details

| Container | Version | Port | DB Client |
|-----------|---------|------|-----------|
| mariadb-10 | 10.x | 3310 | `mysql` |
| mariadb-11 | 11.x | 3311 | `mariadb` |
| mariadb-12 | 12.x | 3312 | `mariadb` |

Passwords are read from `.env` — see `MARIADB_10_ROOT_PASSWORD`, `MARIADB_11_ROOT_PASSWORD`, `MARIADB_12_ROOT_PASSWORD`.

---

## Troubleshooting

### Agent Not Sending Data

1. Check agent is running:
   ```bash
   docker exec mariadb-10 ps aux | grep newrelic
   ```

2. Check logs for errors:
   ```bash
   docker exec mariadb-10 cat /var/log/newrelic-infra/newrelic-infra.log
   ```

3. Verify license key loaded correctly:
   ```bash
   docker exec mariadb-10 cat /etc/newrelic-infra.yml
   ```

### Integration Not Working

1. Test database connection:
   ```bash
   source load-env.sh
   docker exec mariadb-10 mysql -u${NEWRELIC_DB_USER} -p${NEWRELIC_DB_PASSWORD} -e "SELECT VERSION();"
   ```

2. Check integration config:
   ```bash
   docker exec mariadb-10 cat /etc/newrelic-infra/integrations.d/mysql-config.yml
   ```

3. Run integration manually:
   ```bash
   source load-env.sh
   docker exec mariadb-10 /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql \
     -hostname localhost -port 3306 \
     -username ${NEWRELIC_DB_USER} -password ${NEWRELIC_DB_PASSWORD} \
     -metrics
   ```

---

## New Relic UI

- **Infrastructure > Hosts**: View server metrics
- **Infrastructure > Integrations > MySQL**: View database metrics
- **Alerts**: Set up alerts for critical metrics

## Metrics Collected

- Database connections (active, max)
- Query performance (queries/sec, slow queries)
- InnoDB buffer pool (usage, hit ratio)
- Table locks and waits
- Replication status and lag
- Disk I/O and storage usage

---

## Important Notes

⚠️ **Container Recreation**: If you recreate containers with `docker-compose down` or rebuild images, you'll need to run `setup-newrelic.sh` again. Any manually replaced binaries will also be lost.

💡 **Production Tip**: For production, build custom Docker images with New Relic pre-installed (see [NEWRELIC_SETUP.md](NEWRELIC_SETUP.md) for details).

🔐 **Security**: All credentials are managed via `.env`. The `.env` file is git-ignored and never committed.
