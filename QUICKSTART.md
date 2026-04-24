# 🚀 MariaDB Multi-Version Quick Start Guide

Follow these steps to get MariaDB versions 10, 11, and 12 running in Docker.

---

## ✅ Step 1: Verify Docker is Running

```bash
docker --version
docker-compose --version
```

You should see version numbers. If not, install Docker Desktop first.

---

## ✅ Step 2: Start All MariaDB Containers

```bash
docker-compose up -d
```

**What this does:**
- Downloads MariaDB images (first time only, may take a few minutes)
- Creates 3 containers: `mariadb-10`, `mariadb-11`, `mariadb-12`
- Runs initialization scripts to create sample database and tables
- Starts all containers in the background

**Expected output:**
```
Creating network "mariadb-docker-setup_mariadb-network" ... done
Creating volume "mariadb-docker-setup_mariadb_10_data" ... done
Creating volume "mariadb-docker-setup_mariadb_11_data" ... done
Creating volume "mariadb-docker-setup_mariadb_12_data" ... done
Creating mariadb-10 ... done
Creating mariadb-11 ... done
Creating mariadb-12 ... done
```

---

## ✅ Step 3: Verify Containers Are Running

```bash
docker-compose ps
```

**Expected output:**
```
    Name                 Command               State           Ports
---------------------------------------------------------------------------
mariadb-10    docker-entrypoint.sh mariadbd    Up      0.0.0.0:3310->3306/tcp
mariadb-11    docker-entrypoint.sh mariadbd    Up      0.0.0.0:3311->3306/tcp
mariadb-12    docker-entrypoint.sh mariadbd    Up      0.0.0.0:3312->3306/tcp
```

All containers should show "Up" and "healthy" status.

**Tip:** If containers just started, wait 10-15 seconds for full initialization.

---

## ✅ Step 4: Test Queries Across All Versions (Automated)

```bash
./test-all-versions.sh
```

**What this does:**
- Runs the same queries from `test-queries.sql` on all 3 versions
- Shows which queries work on each version
- Highlights any compatibility issues

---

## 🔌 Step 5: Connect Manually to Each Version

You have **two options** to connect manually:

### Option A: Connect from Inside Docker Container (Recommended)

#### Connect to MariaDB 10
```bash
docker exec -it mariadb-10 mysql -uroot -prootpass10 qpm_test
```

#### Connect to MariaDB 11
```bash
docker exec -it mariadb-11 mysql -uroot -prootpass11 qpm_test
```

#### Connect to MariaDB 12
```bash
docker exec -it mariadb-12 mysql -uroot -prootpass12 qpm_test
```

**Once connected, try some queries:**
```sql
-- Check version
SELECT VERSION();

-- Show all users
SELECT * FROM users;

-- Count records
SELECT COUNT(*) FROM users;

-- Exit when done
exit;
```

---

### Option B: Connect from Your Mac (Host Machine)

First, check if you have MySQL client installed:

```bash
mysql --version
```

If not installed, install it:
```bash
brew install mysql-client
```

Then connect:

#### Connect to MariaDB 10
```bash
mysql -h 127.0.0.1 -P 3310 -uroot -prootpass10 qpm_test
```

#### Connect to MariaDB 11
```bash
mysql -h 127.0.0.1 -P 3311 -uroot -prootpass11 qpm_test
```

#### Connect to MariaDB 12
```bash
mysql -h 127.0.0.1 -P 3312 -uroot -prootpass12 qpm_test
```

---

## 📝 Step 6: Run Your Own Queries

### Method 1: Interactive Mode (Inside Container)

```bash
# Connect to any version
docker exec -it mariadb-10 mysql -uroot -prootpass10 qpm_test

# Type your queries
SELECT * FROM users;
```

### Method 2: Run SQL File

```bash
# Edit test-queries.sql with your queries, then:

# Run on MariaDB 10
docker exec -i mariadb-10 mysql -uroot -prootpass10 qpm_test < test-queries.sql

# Run on MariaDB 11
docker exec -i mariadb-11 mysql -uroot -prootpass11 qpm_test < test-queries.sql

# Run on MariaDB 12
docker exec -i mariadb-12 mysql -uroot -prootpass12 qpm_test < test-queries.sql
```

### Method 3: One-Line Query

```bash
# Single query on MariaDB 10
echo "SELECT VERSION();" | docker exec -i mariadb-10 mysql -uroot -prootpass10 qpm_test

# Single query on MariaDB 11
echo "SELECT COUNT(*) FROM users;" | docker exec -i mariadb-11 mysql -uroot -prootpass11 qpm_test
```

---

## 🎯 Complete Workflow Example

Here's a typical workflow for testing a query across all versions:

```bash
# 1. Start containers
docker-compose up -d

# 2. Wait for initialization (10-15 seconds)
sleep 15

# 3. Check status
docker-compose ps

# 4. Run your query on each version
echo "SELECT VERSION();" | docker exec -i mariadb-10 mysql -uroot -prootpass10 qpm_test
echo "SELECT VERSION();" | docker exec -i mariadb-11 mysql -uroot -prootpass11 qpm_test
echo "SELECT VERSION();" | docker exec -i mariadb-12 mysql -uroot -prootpass12 qpm_test

# 5. Or run a full SQL file on all versions
docker exec -i mariadb-10 mysql -uroot -prootpass10 qpm_test < my-query.sql
docker exec -i mariadb-11 mysql -uroot -prootpass11 qpm_test < my-query.sql
docker exec -i mariadb-12 mysql -uroot -prootpass12 qpm_test < my-query.sql
```

---

## 🛑 Stopping and Cleaning Up

### Stop All Containers (Keep Data)
```bash
docker-compose stop
```

### Stop and Remove Containers (Keep Data)
```bash
docker-compose down
```

### Stop, Remove Containers AND Delete All Data
```bash
docker-compose down -v
```

---

## 🔍 Useful Monitoring Commands

### View Live Logs (All Versions)
```bash
docker-compose logs -f
```

### View Logs for Specific Version
```bash
docker-compose logs -f mariadb-10
docker-compose logs -f mariadb-11
docker-compose logs -f mariadb-12
```

### Check Container Health
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### Restart a Specific Version
```bash
docker-compose restart mariadb-10
docker-compose restart mariadb-11
docker-compose restart mariadb-12
```

---

## 📚 Quick Reference

### Connection Details

| Version | Container Name | Port | Root Password | Database | User     | User Password |
|---------|---------------|------|---------------|----------|----------|---------------|
| v10     | mariadb-10    | 3310 | rootpass10    | qpm_test   | testuser | testpass      |
| v11     | mariadb-11    | 3311 | rootpass11    | qpm_test   | testuser | testpass      |
| v12     | mariadb-12    | 3312 | rootpass12    | qpm_test   | testuser | testpass      |

### File Locations

- **Main config:** `docker-compose.yml`
- **Init scripts:** `init-scripts/v10/`, `init-scripts/v11/`, `init-scripts/v12/`
- **Test queries:** `test-queries.sql`
- **Test script:** `test-all-versions.sh`

---

## ⚡ Pro Tips

1. **Use the test script** to quickly verify all versions: `./test-all-versions.sh`

2. **Connect with username/password** instead of root:
   ```bash
   docker exec -it mariadb-10 mysql -utestuser -ptestpass qpm_test
   ```

3. **Run multiple queries at once:**
   ```bash
   docker exec -i mariadb-10 mysql -uroot -prootpass10 qpm_test << EOF
   SELECT VERSION();
   SELECT * FROM users;
   CALL GetUserCount();
   EOF
   ```

4. **Export query results to file:**
   ```bash
   docker exec -i mariadb-10 mysql -uroot -prootpass10 qpm_test -e "SELECT * FROM users;" > output.txt
   ```

5. **Compare outputs across versions:**
   ```bash
   docker exec -i mariadb-10 mysql -uroot -prootpass10 qpm_test -e "SELECT VERSION();" > v10-output.txt
   docker exec -i mariadb-11 mysql -uroot -prootpass11 qpm_test -e "SELECT VERSION();" > v11-output.txt
   docker exec -i mariadb-12 mysql -uroot -prootpass12 qpm_test -e "SELECT VERSION();" > v12-output.txt
   diff v10-output.txt v11-output.txt
   ```

---

## 🆘 Troubleshooting

### Problem: Containers won't start
```bash
# Check logs
docker-compose logs

# Remove old containers and try again
docker-compose down
docker-compose up -d
```

### Problem: Port already in use
```bash
# Check what's using the port
lsof -i :3310
lsof -i :3311
lsof -i :3312

# Change ports in docker-compose.yml if needed
```

### Problem: Can't connect to database
```bash
# Wait longer for initialization
docker-compose ps

# Check container logs
docker-compose logs mariadb-10

# Restart the container
docker-compose restart mariadb-10
```

### Problem: Need to reset everything
```bash
# Complete clean slate
docker-compose down -v
docker-compose up -d
```

---

## ✅ Success Checklist

- [ ] Docker is installed and running
- [ ] `docker-compose up -d` completed successfully
- [ ] `docker-compose ps` shows all containers as "Up"
- [ ] `./test-all-versions.sh` runs without errors
- [ ] Can connect manually to each version
- [ ] Can run queries on all versions

**You're all set!** 🎉

For more details, see [README.md](README.md)
