#!/bin/bash

# Script to test queries across all MariaDB versions
# This script runs the same SQL queries on all three versions

# Load environment variables
source "$(dirname "$0")/load-env.sh"

echo "======================================"
echo "Testing MariaDB Versions 10, 11, 12"
echo "======================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to test a specific version
test_version() {
    local version=$1
    local port=$2
    local password=$3
    
    echo -e "${YELLOW}Testing MariaDB Version $version (Port: $port)${NC}"
    echo "--------------------------------------"
    
    # Check if container is running
    if ! docker ps | grep -q "mariadb-$version"; then
        echo -e "${RED}ERROR: MariaDB $version container is not running!${NC}"
        echo ""
        return 1
    fi
    
    # Determine which command to use (mysql for v10, mariadb for v11+)
    local db_command="mysql"
    if [ "$version" -ge 11 ]; then
        db_command="mariadb"
    fi
    
    # Run test queries
    if docker exec -i mariadb-$version $db_command -uroot -p$password testdb < test-queries.sql 2>/dev/null; then
        echo -e "${GREEN}✓ MariaDB $version: All queries executed successfully${NC}"
    else
        echo -e "${RED}✗ MariaDB $version: Some queries failed${NC}"
    fi
    
    echo ""
}

# Check if containers are running
echo "Checking container status..."
docker-compose ps
echo ""

# Test each version
test_version "10" "$MARIADB_10_PORT" "$MARIADB_10_ROOT_PASSWORD"
test_version "11" "$MARIADB_11_PORT" "$MARIADB_11_ROOT_PASSWORD"
test_version "12" "$MARIADB_12_PORT" "$MARIADB_12_ROOT_PASSWORD"

echo "======================================"
echo "Testing Complete"
echo "======================================"
echo ""
echo "To connect to each version manually:"
echo "  MariaDB 10: docker exec -it mariadb-10 mysql -uroot -p$MARIADB_10_ROOT_PASSWORD $MARIADB_10_DATABASE"
echo "  MariaDB 11: docker exec -it mariadb-11 mariadb -uroot -p$MARIADB_11_ROOT_PASSWORD $MARIADB_11_DATABASE"
echo "  MariaDB 12: docker exec -it mariadb-12 mariadb -uroot -p$MARIADB_12_ROOT_PASSWORD $MARIADB_12_DATABASE"
echo ""
echo "Or connect from host:"
echo "  MariaDB 10: mysql -h 127.0.0.1 -P $MARIADB_10_PORT -uroot -p$MARIADB_10_ROOT_PASSWORD $MARIADB_10_DATABASE"
echo "  MariaDB 11: mariadb -h 127.0.0.1 -P $MARIADB_11_PORT -uroot -p$MARIADB_11_ROOT_PASSWORD $MARIADB_11_DATABASE"
echo "  MariaDB 12: mariadb -h 127.0.0.1 -P 3312 -uroot -prootpass12 testdb"
