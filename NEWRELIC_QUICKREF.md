# New Relic Quick Reference

## Quick Setup

```bash
# 1. Set your license key
export NEW_RELIC_LICENSE_KEY="your_license_key_here"

# 2. Run automated setup
./setup-newrelic.sh
```

## Monitoring User Credentials

- **Username**: `newrelic`
- **Password**: `NewRelic123!`
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
```bash
docker exec mariadb-10 /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql \
  -hostname localhost \
  -port 3306 \
  -username newrelic \
  -password NewRelic123! \
  -metrics
```

### Restart Agent
```bash
docker exec mariadb-10 service newrelic-infra restart
```

### Check MySQL User
```bash
docker exec mariadb-10 mysql -uroot -prootpass10 -e "SHOW GRANTS FOR 'newrelic'@'localhost';"
```

## Configuration Files

| File | Location |
|------|----------|
| Agent Config | `/etc/newrelic-infra.yml` |
| MySQL Integration | `/etc/newrelic-infra/integrations.d/mysql-config.yml` |
| Agent Logs | `/var/log/newrelic-infra/newrelic-infra.log` |

## Container Details

| Container | Version | Port | Root Password | Display Name |
|-----------|---------|------|---------------|--------------|
| mariadb-10 | 10.x | 3310 | rootpass10 | mariadb-10 |
| mariadb-11 | 11.x | 3311 | rootpass11 | mariadb-11 |
| mariadb-12 | 12.x | 3312 | rootpass12 | mariadb-12 |

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

3. Verify license key:
   ```bash
   docker exec mariadb-10 cat /etc/newrelic-infra.yml
   ```

### Integration Not Working

1. Test database connection:
   ```bash
   docker exec mariadb-10 mysql -unewrelic -pNewRelic123! -e "SELECT VERSION();"
   ```

2. Check integration config:
   ```bash
   docker exec mariadb-10 cat /etc/newrelic-infra/integrations.d/mysql-config.yml
   ```

3. Run integration manually:
   ```bash
   docker exec mariadb-10 /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql \
     -hostname localhost -port 3306 -username newrelic -password NewRelic123! -metrics
   ```

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

## Important Notes

⚠️ **Container Recreation**: If you recreate containers with `docker-compose down` or rebuild images, you'll need to run `setup-newrelic.sh` again.

💡 **Production Tip**: For production, build custom Docker images with New Relic pre-installed (see [NEWRELIC_SETUP.md](NEWRELIC_SETUP.md) for details).

🔐 **Security**: Store credentials securely using Docker secrets or encrypted environment files in production.
