#!/bin/sh
# Startup script for the single New Relic agent container.
# Generates one nri-mysql integration config with all three MariaDB instances,
# then starts the infrastructure agent.
#
# Required environment variables (set in docker-compose via .env):
#   NEWRELIC_DB_USER     - MariaDB monitoring user
#   NEWRELIC_DB_PASSWORD - MariaDB monitoring password

set -e

mkdir -p /etc/newrelic-infra/integrations.d

cat > /etc/newrelic-infra/integrations.d/mysql-config.yml << EOF
integrations:
  - name: nri-mysql
    env:
      HOSTNAME: mariadb-10
      PORT: 3306
      USERNAME: ${NEWRELIC_DB_USER}
      PASSWORD: ${NEWRELIC_DB_PASSWORD}
      DATABASE: testdb
      REMOTE_MONITORING: "true"
      METRICS: "true"
      INVENTORY: "true"
      EXTENDED_METRICS: "true"
      EXTENDED_INNODB_METRICS: "true"
      EXTENDED_MY_ISAM_METRICS: "true"
      ENABLE_QUERY_MONITORING: "true"
    interval: 30s
    labels:
      env: development
      role: database
      version: "10"
    inventory_source: config/mysql

  - name: nri-mysql
    env:
      HOSTNAME: mariadb-11
      PORT: 3306
      USERNAME: ${NEWRELIC_DB_USER}
      PASSWORD: ${NEWRELIC_DB_PASSWORD}
      DATABASE: testdb
      REMOTE_MONITORING: "true"
      METRICS: "true"
      INVENTORY: "true"
      EXTENDED_METRICS: "true"
      EXTENDED_INNODB_METRICS: "true"
      EXTENDED_MY_ISAM_METRICS: "true"
      ENABLE_QUERY_MONITORING: "true"
    interval: 30s
    labels:
      env: development
      role: database
      version: "11"
    inventory_source: config/mysql

  - name: nri-mysql
    env:
      HOSTNAME: mariadb-12
      PORT: 3306
      USERNAME: ${NEWRELIC_DB_USER}
      PASSWORD: ${NEWRELIC_DB_PASSWORD}
      DATABASE: testdb
      REMOTE_MONITORING: "true"
      METRICS: "true"
      INVENTORY: "true"
      EXTENDED_METRICS: "true"
      EXTENDED_INNODB_METRICS: "true"
      EXTENDED_MY_ISAM_METRICS: "true"
      ENABLE_QUERY_MONITORING: "true"
    interval: 30s
    labels:
      env: development
      role: database
      version: "12"
    inventory_source: config/mysql
EOF

echo "[entrypoint] mysql-config.yml written for mariadb-10, mariadb-11, mariadb-12"

exec newrelic-infra
