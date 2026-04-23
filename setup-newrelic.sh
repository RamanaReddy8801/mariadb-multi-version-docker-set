#!/bin/bash

#############################################
# New Relic Setup Script for MariaDB Containers
#
# What this script does:
#   Creates the New Relic monitoring user in each MariaDB database.
#   The user is created with host '%' so the dedicated New Relic agent
#   container (on the same Docker network) can connect by container name.
#
# The single New Relic agent container is managed by docker-compose
# (newrelic-agent) using the newrelic/infrastructure-bundle image with
# nri-mysql included. It monitors all three MariaDB instances.
#############################################

set -e  # Exit on error

# Load environment variables
source "$(dirname "$0")/load-env.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Monitoring user credentials — must be set in .env
NEWRELIC_DB_USER="${NEWRELIC_DB_USER:?'NEWRELIC_DB_USER must be set in .env'}"
NEWRELIC_DB_PASSWORD="${NEWRELIC_DB_PASSWORD:?'NEWRELIC_DB_PASSWORD must be set in .env'}"

print_info()    { echo -e "${BLUE}ℹ ${NC}$1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error()   { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_header() {
    echo ""
    echo -e "${YELLOW}======================================${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}======================================${NC}"
    echo ""
}

# Check license key is set (needed by agent containers via docker-compose)
check_license_key() {
    if [ -z "$NEW_RELIC_LICENSE_KEY" ]; then
        print_error "NEW_RELIC_LICENSE_KEY is not set in .env!"
        echo ""
        echo "Add it to your .env file:"
        echo "  NEW_RELIC_LICENSE_KEY=your_license_key_here"
        echo ""
        exit 1
    fi
    print_success "License key found"
}

# Check container is running
check_container() {
    local container=$1
    if ! docker ps | grep -q "$container"; then
        print_error "Container $container is not running!"
        return 1
    fi
    print_success "Container $container is running"
    return 0
}

# Create monitoring user with host '%' so the agent container can connect
# over the Docker network (not just localhost inside the same container)
create_monitoring_user() {
    local container=$1
    local db_command=$2
    local root_password=$3

    print_info "Creating monitoring user '${NEWRELIC_DB_USER}'@'%' in $container..."

    docker exec $container $db_command -uroot -p${root_password} -e "
        CREATE USER IF NOT EXISTS '${NEWRELIC_DB_USER}'@'%' IDENTIFIED BY '${NEWRELIC_DB_PASSWORD}';
        GRANT REPLICATION CLIENT ON *.* TO '${NEWRELIC_DB_USER}'@'%';
        GRANT SELECT ON *.* TO '${NEWRELIC_DB_USER}'@'%';
        GRANT PROCESS ON *.* TO '${NEWRELIC_DB_USER}'@'%';
        FLUSH PRIVILEGES;
    " 2>/dev/null || {
        print_error "Failed to create monitoring user in $container"
        return 1
    }

    print_success "Monitoring user created in $container"
    return 0
}

# Verify the monitoring user can connect from inside the container
verify_user_connection() {
    local container=$1
    local db_command=$2

    print_info "Verifying monitoring user connection in $container..."

    if docker exec $container $db_command \
        -u${NEWRELIC_DB_USER} -p${NEWRELIC_DB_PASSWORD} \
        -e "SELECT 1;" > /dev/null 2>&1; then
        print_success "Monitoring user connection verified"
        return 0
    else
        print_error "Failed to verify monitoring user connection"
        return 1
    fi
}

# Setup monitoring user for a single container
setup_container() {
    local container=$1
    local db_command=$2
    local root_password=$3

    print_header "Setting up monitoring user in $container"

    check_container "$container"   || return 1
    create_monitoring_user "$container" "$db_command" "$root_password" || return 1
    verify_user_connection "$container" "$db_command" || return 1

    print_success "Done: $container"
    echo ""
    return 0
}

# Resolve container args (name -> db command, root password)
get_container_args() {
    case "$1" in
        mariadb-10) echo "mysql $MARIADB_10_ROOT_PASSWORD" ;;
        mariadb-11) echo "mariadb $MARIADB_11_ROOT_PASSWORD" ;;
        mariadb-12) echo "mariadb $MARIADB_12_ROOT_PASSWORD" ;;
        *)
            print_error "Unknown container: $1  (valid: mariadb-10, mariadb-11, mariadb-12)"
            exit 1
            ;;
    esac
}

# Main
# Usage:
#   ./setup-newrelic.sh               — create monitoring user in all three containers
#   ./setup-newrelic.sh mariadb-10    — create monitoring user in one container only
main() {
    local target="${1:-}"

    print_header "New Relic Monitoring User Setup"

    check_license_key

    echo ""
    print_info "This script will create the monitoring user '${NEWRELIC_DB_USER}'@'%'"
    print_info "in each MariaDB container so the New Relic agent containers can connect."
    if [ -n "$target" ]; then
        echo ""
        print_info "Target: $target only"
    fi
    echo ""

    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Setup cancelled"
        exit 0
    fi

    if [ -n "$target" ]; then
        read -r db_cmd root_pass <<< "$(get_container_args "$target")"
        setup_container "$target" "$db_cmd" "$root_pass"
    else
        setup_container "mariadb-10" "mysql"    "$MARIADB_10_ROOT_PASSWORD"
        setup_container "mariadb-11" "mariadb"  "$MARIADB_11_ROOT_PASSWORD"
        setup_container "mariadb-12" "mariadb"  "$MARIADB_12_ROOT_PASSWORD"
    fi

    print_header "Monitoring Users Ready!"

    echo "Next step — start the New Relic agent container:"
    echo ""
    echo "  docker-compose up -d newrelic-agent"
    echo ""
    echo "Or if starting everything from scratch:"
    echo ""
    echo "  docker-compose up -d"
    echo ""
    echo "Verify agent is running:"
    echo ""
    echo "  docker ps | grep newrelic-agent"
    echo ""
    echo "Check agent logs:"
    echo ""
    echo "  docker logs newrelic-agent -f"
    echo ""
    print_info "Data appears in New Relic UI after ~2 minutes:"
    echo "  Infrastructure > Hosts          (look for mariadb-10, mariadb-11, mariadb-12)"
    echo "  Infrastructure > Integrations > MySQL"
    echo ""
}

main "$@"
