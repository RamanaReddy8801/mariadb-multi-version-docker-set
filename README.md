# MariaDB Docker Setup - Multi-Version Testing

This setup allows you to run MariaDB versions 10, 11, and 12 simultaneously using Docker, with each version running on a separate port.

## 📋 Prerequisites

- Docker installed and running
- Docker Compose installed
- At least 2GB of free disk space

## ⚙️ Environment Setup

This project uses environment variables for secure credential management.

### Quick Setup (For Testing)

The repository includes a default `.env` file for immediate testing. If it's missing, create it:

```bash
cp .env.example .env
```

**Default credentials are set for quick testing. Change them for production use!**

### Custom Setup (Recommended for Production)

1. **Create your environment file:**
   ```bash
   cp .env.example .env
   ```

2. **Edit `.env` with your credentials:**
   ```bash
   nano .env
   # or use your preferred editor
   ```

3. **Set strong passwords:**
   ```bash
   # Example .env content
   MARIADB_10_ROOT_PASSWORD=StrongP@ssw0rd123!
   MARIADB_10_DATABASE=myapp_db
   MARIADB_10_USER=myapp_user
   MARIADB_10_PASSWORD=AnotherStr0ng!Pass
   MARIADB_10_PORT=3310
   
   # Repeat for MariaDB 11 and 12...
   ```

4. **Secure your `.env` file:**
   ```bash
   chmod 600 .env
   ```

**📖 For detailed configuration options, see [ENV_SETUP.md](ENV_SETUP.md)**

**🔐 Security Note:** The `.env` file is git-ignored and will never be committed. Only `.env.example` (with placeholder values) is tracked.

## 🚀 Quick Start

### 1. Setup Environment (First Time Only)

If you haven't already, set up your environment variables:
```bash
cp .env.example .env
# Edit .env if you want custom credentials
```

### 2. Start All MariaDB Versions

```bash
docker-compose up -d
```

This will:
- Pull the required MariaDB images (if not already downloaded)
- Create three separate containers (mariadb-10, mariadb-11, mariadb-12)
- Initialize each with sample data from the init scripts
- Expose ports 3310, 3311, and 3312 respectively
- Use credentials from your `.env` file

### 3. Check Container Status

```bash
docker-compose ps
```

All containers should show as "healthy" after a few seconds.

### 4. Run Test Queries Across All Versions

```bash
./test-all-versions.sh
```

This script will execute the same queries on all three versions to verify compatibility.

## 🔌 Connection Details

**Default credentials** (can be changed in `.env` file):

### MariaDB 10
- **Container Name**: mariadb-10
- **Port**: 3310
- **Root Password**: rootpass10 (from `.env`)
- **Database**: testdb (from `.env`)
- **User**: testuser (from `.env`)
- **User Password**: testpass (from `.env`)

### MariaDB 11
- **Container Name**: mariadb-11
- **Port**: 3311
- **Root Password**: rootpass11 (from `.env`)
- **Database**: testdb (from `.env`)
- **User**: testuser (from `.env`)
- **User Password**: testpass (from `.env`)

### MariaDB 12
- **Container Name**: mariadb-12
- **Port**: 3312
- **Root Password**: rootpass12 (from `.env`)
- **Database**: testdb (from `.env`)
- **User**: testuser (from `.env`)
- **User Password**: testpass (from `.env`)

## 💻 Connecting to Each Version

**Note:** These examples use default credentials from `.env`. If you changed your credentials, replace the passwords accordingly.

### From Inside the Container

```bash
# MariaDB 10
docker exec -it mariadb-10 mysql -uroot -prootpass10 testdb

# MariaDB 11
docker exec -it mariadb-11 mariadb -uroot -prootpass11 testdb

# MariaDB 12
docker exec -it mariadb-12 mariadb -uroot -prootpass12 testdb
```

### From Your Host Machine

If you have MySQL client installed on your host:

```bash
# MariaDB 10
mysql -h 127.0.0.1 -P 3310 -uroot -prootpass10 testdb

# MariaDB 11
mysql -h 127.0.0.1 -P 3311 -uroot -prootpass11 testdb

# MariaDB 12
mysql -h 127.0.0.1 -P 3312 -uroot -prootpass12 testdb
```

### Using Docker Exec with SQL File

```bash
# Run queries from a file on MariaDB 10
docker exec -i mariadb-10 mysql -uroot -prootpass10 testdb < your-queries.sql

# Run queries from a file on MariaDB 11
docker exec -i mariadb-11 mysql -uroot -prootpass11 testdb < your-queries.sql

# Run queries from a file on MariaDB 12
docker exec -i mariadb-12 mysql -uroot -prootpass12 testdb < your-queries.sql
```

## 📁 File Structure

```
mariadb-docker-setup/
├── docker-compose.yml          # Main orchestration file
├── init-scripts/               # Initialization scripts
│   ├── v10/
│   │   └── init.sql           # MariaDB 10 init script
│   ├── v11/
│   │   └── init.sql           # MariaDB 11 init script
│   └── v12/
│       └── init.sql           # MariaDB 12 init script
├── test-queries.sql            # Sample queries to test
├── test-all-versions.sh        # Script to test all versions
└── README.md                   # This file
```

## 🧪 Testing Your Queries

1. **Edit** `test-queries.sql` with your own queries
2. **Run** the test script:
   ```bash
   ./test-all-versions.sh
   ```
3. **Review** the output to see if queries work across all versions

## 🛠️ Useful Commands

### View Logs

```bash
# All containers
docker-compose logs -f

# Specific version
docker-compose logs -f mariadb-10
docker-compose logs -f mariadb-11
docker-compose logs -f mariadb-12
```

### Stop All Containers

```bash
docker-compose down
```

### Stop and Remove Data

```bash
docker-compose down -v
```

### Restart a Specific Version

```bash
docker-compose restart mariadb-10
docker-compose restart mariadb-11
docker-compose restart mariadb-12
```

### Start Only One Version

```bash
# Start only MariaDB 10
docker-compose up -d mariadb-10

# Start only MariaDB 11
docker-compose up -d mariadb-11

# Start only MariaDB 12
docker-compose up -d mariadb-12
```

## 📊 Data Persistence

Each version has its own named volume for data persistence:
- `mariadb_10_data` - MariaDB 10 data
- `mariadb_11_data` - MariaDB 11 data
- `mariadb_12_data` - MariaDB 12 data

Data persists even when containers are stopped or removed (unless you use `docker-compose down -v`).

## 🔄 Resetting a Version

To reset a specific version to its initial state:

```bash
# Stop the container
docker-compose stop mariadb-10

# Remove the volume
docker volume rm mariadb-docker-setup_mariadb_10_data

# Start again (will reinitialize)
docker-compose up -d mariadb-10
```

## 🔒 Security Note

**Warning**: The passwords in this setup are for development/testing only. For production use:
- Use strong passwords
- Store passwords in environment files (`.env`)
- Never commit passwords to version control
- Restrict network access appropriately

## 🎯 Common Use Cases

### Testing Query Compatibility

Run the same query on all versions to check compatibility:

```bash
# Example: Test a specific query
echo "SELECT VERSION();" | docker exec -i mariadb-10 mysql -uroot -prootpass10 testdb
echo "SELECT VERSION();" | docker exec -i mariadb-11 mysql -uroot -prootpass11 testdb
echo "SELECT VERSION();" | docker exec -i mariadb-12 mysql -uroot -prootpass12 testdb
```

### Benchmarking

Compare performance across versions using your own benchmark scripts.

### Migration Testing

Test database migrations before applying them to production.

## 📝 Customization

### Adding Custom Initialization

Add more `.sql` files to the respective `init-scripts/v*/` directories. They will be executed in alphabetical order.

### Changing Ports

Edit the `ports` section in `docker-compose.yml`:

```yaml
ports:
  - "YOUR_PORT:3306"
```

### Adding More Versions

Copy and modify a service block in `docker-compose.yml` to add additional versions.

## 🐛 Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose logs mariadb-10

# Check if port is already in use
lsof -i :3310
```

### Connection Refused

- Wait 10-15 seconds after starting for containers to fully initialize
- Check if containers are healthy: `docker-compose ps`
- Verify ports are not blocked by firewall

### Out of Memory

Reduce the number of running containers or increase Docker's memory allocation.

## � New Relic Monitoring (Optional)

Want to monitor your MariaDB containers with New Relic? We've got you covered!

### Quick Setup

```bash
# 1. Add credentials to .env
NEW_RELIC_LICENSE_KEY=your_license_key_here
NEWRELIC_DB_USER=newrelic
NEWRELIC_DB_PASSWORD=your_monitor_password_here

# 2. Run automated setup
./setup-newrelic.sh
```

This will install and configure:
- New Relic Infrastructure agent in each container
- MySQL/MariaDB integration for monitoring
- Monitoring user with appropriate permissions
- Integration configuration files

### Documentation

- **[NEWRELIC_SETUP.md](NEWRELIC_SETUP.md)** - Complete setup guide with manual instructions
- **[NEWRELIC_QUICKREF.md](NEWRELIC_QUICKREF.md)** - Quick reference for common commands and troubleshooting

### What Gets Monitored

- Database connections and query performance
- InnoDB buffer pool and cache metrics
- Replication status and lag
- Table sizes and row counts
- Slow queries and lock waits
- Server resource usage (CPU, memory, disk)

After setup, view your metrics in New Relic:
- **Infrastructure > Hosts**: Server-level metrics
- **Infrastructure > Integrations > MySQL**: Database-specific metrics

## 📚 Additional Resources

- [MariaDB Documentation](https://mariadb.com/kb/en/documentation/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [MariaDB Docker Hub](https://hub.docker.com/_/mariadb)
- [New Relic Infrastructure Agent](https://docs.newrelic.com/docs/infrastructure/install-infrastructure-agent/)
