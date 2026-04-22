# New Relic Setup Guide for MariaDB Docker Containers

This guide explains how to install and configure New Relic Infrastructure agent and MySQL integration for monitoring your MariaDB containers.

## Prerequisites

- Docker containers running (mariadb-10, mariadb-11, mariadb-12)
- New Relic account with a License Key
- Root access to containers

## Overview

The setup includes:
1. Installing New Relic Infrastructure agent in each container
2. Installing MySQL/MariaDB integration
3. Creating a monitoring user in each database
4. Configuring the integration
5. Verifying the connection

## Quick Setup (Automated)

Run the automated setup script:

```bash
# Set your New Relic license key
export NEW_RELIC_LICENSE_KEY="your_license_key_here"

# Run the setup script
./setup-newrelic.sh
```

## Manual Setup Steps

### Step 1: Set Environment Variables

```bash
export NEW_RELIC_LICENSE_KEY="your_license_key_here"
```

### Step 2: Install New Relic Infrastructure Agent in Each Container

For each container (mariadb-10, mariadb-11, mariadb-12):

```bash
# Update package lists and install dependencies
docker exec -it mariadb-10 bash -c "
  apt-get update && \
  apt-get install -y curl gnupg apt-transport-https ca-certificates
"

# Add New Relic's GPG key and repository
docker exec -it mariadb-10 bash -c "
  curl -s https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | apt-key add - && \
  echo 'deb https://download.newrelic.com/infrastructure_agent/linux/apt jammy main' > /etc/apt/sources.list.d/newrelic-infra.list
"

# Install the Infrastructure agent
docker exec -it mariadb-10 bash -c "
  apt-get update && \
  apt-get install -y newrelic-infra
"

# Configure the license key
docker exec -it mariadb-10 bash -c "
  echo 'license_key: ${NEW_RELIC_LICENSE_KEY}' > /etc/newrelic-infra.yml && \
  echo 'display_name: mariadb-10' >> /etc/newrelic-infra.yml
"
```

Repeat for mariadb-11 and mariadb-12.

### Step 3: Create Monitoring User in Each Database

#### For MariaDB 10:

```bash
docker exec -it mariadb-10 mysql -uroot -prootpass10 -e "
  CREATE USER IF NOT EXISTS 'newrelic'@'localhost' IDENTIFIED BY 'NewRelic123!';
  GRANT REPLICATION CLIENT ON *.* TO 'newrelic'@'localhost';
  GRANT SELECT ON *.* TO 'newrelic'@'localhost';
  FLUSH PRIVILEGES;
"
```

#### For MariaDB 11:

```bash
docker exec -it mariadb-11 mariadb -uroot -prootpass11 -e "
  CREATE USER IF NOT EXISTS 'newrelic'@'localhost' IDENTIFIED BY 'NewRelic123!';
  GRANT REPLICATION CLIENT ON *.* TO 'newrelic'@'localhost';
  GRANT SELECT ON *.* TO 'newrelic'@'localhost';
  FLUSH PRIVILEGES;
"
```

#### For MariaDB 12:

```bash
docker exec -it mariadb-12 mariadb -uroot -prootpass12 -e "
  CREATE USER IF NOT EXISTS 'newrelic'@'localhost' IDENTIFIED BY 'NewRelic123!';
  GRANT REPLICATION CLIENT ON *.* TO 'newrelic'@'localhost';
  GRANT SELECT ON *.* TO 'newrelic'@'localhost';
  FLUSH PRIVILEGES;
"
```

### Step 4: Install MySQL Integration

For each container:

```bash
# Install the integration package
docker exec -it mariadb-10 apt-get install -y nri-mysql

# Create integration configuration directory if it doesn't exist
docker exec -it mariadb-10 mkdir -p /etc/newrelic-infra/integrations.d
```

Repeat for mariadb-11 and mariadb-12.

### Step 5: Create MySQL Integration Configuration

#### For MariaDB 10:

```bash
docker exec -it mariadb-10 bash -c "cat > /etc/newrelic-infra/integrations.d/mysql-config.yml << 'EOF'
integrations:
  - name: nri-mysql
    env:
      HOSTNAME: localhost
      PORT: 3306
      USERNAME: newrelic
      PASSWORD: NewRelic123!
      DATABASE: testdb
      METRICS: true
      INVENTORY: true
      EXTENDED_METRICS: true
      EXTENDED_INNODB_METRICS: true
      EXTENDED_MY_ISAM_METRICS: true
    interval: 30s
    labels:
      env: development
      role: database
      version: '10'
    inventory_source: config/mysql
EOF
"
```

#### For MariaDB 11:

```bash
docker exec -it mariadb-11 bash -c "cat > /etc/newrelic-infra/integrations.d/mysql-config.yml << 'EOF'
integrations:
  - name: nri-mysql
    env:
      HOSTNAME: localhost
      PORT: 3306
      USERNAME: newrelic
      PASSWORD: NewRelic123!
      DATABASE: testdb
      METRICS: true
      INVENTORY: true
      EXTENDED_METRICS: true
      EXTENDED_INNODB_METRICS: true
      EXTENDED_MY_ISAM_METRICS: true
    interval: 30s
    labels:
      env: development
      role: database
      version: '11'
    inventory_source: config/mysql
EOF
"
```

#### For MariaDB 12:

```bash
docker exec -it mariadb-12 bash -c "cat > /etc/newrelic-infra/integrations.d/mysql-config.yml << 'EOF'
integrations:
  - name: nri-mysql
    env:
      HOSTNAME: localhost
      PORT: 3306
      USERNAME: newrelic
      PASSWORD: NewRelic123!
      DATABASE: testdb
      METRICS: true
      INVENTORY: true
      EXTENDED_METRICS: true
      EXTENDED_INNODB_METRICS: true
      EXTENDED_MY_ISAM_METRICS: true
    interval: 30s
    labels:
      env: development
      role: database
      version: '12'
    inventory_source: config/mysql
EOF
"
```

### Step 6: Start New Relic Infrastructure Agent

For each container:

```bash
docker exec -it mariadb-10 service newrelic-infra start
docker exec -it mariadb-11 service newrelic-infra start
docker exec -it mariadb-12 service newrelic-infra start
```

### Step 7: Verify Connection

#### Test Database Connection:

```bash
# Test MariaDB 10
docker exec -it mariadb-10 mysql -unewrelic -pNewRelic123! -e "SELECT VERSION();"

# Test MariaDB 11
docker exec -it mariadb-11 mariadb -unewrelic -pNewRelic123! -e "SELECT VERSION();"

# Test MariaDB 12
docker exec -it mariadb-12 mariadb -unewrelic -pNewRelic123! -e "SELECT VERSION();"
```

#### Check New Relic Agent Status:

```bash
docker exec -it mariadb-10 service newrelic-infra status
docker exec -it mariadb-11 service newrelic-infra status
docker exec -it mariadb-12 service newrelic-infra status
```

#### Check Integration Logs:

```bash
docker exec -it mariadb-10 tail -f /var/log/newrelic-infra/newrelic-infra.log
```

## Verify in New Relic UI

1. Log in to your New Relic account
2. Navigate to **Infrastructure > Hosts**
3. Look for `mariadb-10`, `mariadb-11`, `mariadb-12` in the hosts list
4. Navigate to **Infrastructure > Integrations > MySQL**
5. You should see metrics from all three databases

## Troubleshooting

### Agent Not Starting

```bash
# Check if systemd/service is running
docker exec -it mariadb-10 ps aux | grep newrelic

# Check for errors in logs
docker exec -it mariadb-10 cat /var/log/newrelic-infra/newrelic-infra.log
```

### Integration Not Working

```bash
# Manually test the integration
docker exec -it mariadb-10 /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql \
  -hostname localhost \
  -port 3306 \
  -username newrelic \
  -password NewRelic123! \
  -metrics
```

### Database Connection Issues

```bash
# Verify user exists and has correct permissions
docker exec -it mariadb-10 mysql -uroot -prootpass10 -e "
  SELECT user, host FROM mysql.user WHERE user='newrelic';
  SHOW GRANTS FOR 'newrelic'@'localhost';
"
```

## Important Notes

1. **Container Persistence**: The New Relic agent is installed inside the containers. If you recreate the containers, you'll need to reinstall.
2. **Production Setup**: For production, consider creating custom Docker images with New Relic pre-installed.
3. **Security**: Store the license key and database passwords securely (use Docker secrets or environment files).
4. **Metrics Interval**: Adjust the `interval` in the config based on your monitoring needs (default: 30s).

## Custom Docker Images (Recommended for Production)

For persistent setups, create custom Dockerfiles:

```dockerfile
FROM mariadb:10

# Install New Relic Infrastructure agent
RUN apt-get update && \
    apt-get install -y curl gnupg apt-transport-https ca-certificates && \
    curl -s https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | apt-key add - && \
    echo 'deb https://download.newrelic.com/infrastructure_agent/linux/apt jammy main' > /etc/apt/sources.list.d/newrelic-infra.list && \
    apt-get update && \
    apt-get install -y newrelic-infra nri-mysql && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy configurations
COPY newrelic-infra.yml /etc/newrelic-infra.yml
COPY mysql-config.yml /etc/newrelic-infra/integrations.d/mysql-config.yml
```

## Monitoring Metrics

The integration collects:
- **Database metrics**: Connections, queries, buffer pool, etc.
- **InnoDB metrics**: Buffer pool usage, log writes, row operations
- **Replication metrics**: Slave status, lag
- **Table metrics**: Size, row count
- **Extended metrics**: Detailed performance data

Check your New Relic dashboard for real-time monitoring!
