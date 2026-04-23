#!/bin/bash

#############################################
# Employees Sample Database Setup Script
#
# What this script does:
#   Downloads the MySQL employees sample database
#   (https://github.com/datacharmer/test_db) and loads it
#   into each running MariaDB container.
#
# The database contains ~300k employees with departments,
#   titles, salaries, and dept assignments — useful for
#   testing complex query patterns and monitoring.
#
# Usage:
#   ./setup-employees-db.sh               — load into all three containers
#   ./setup-employees-db.sh mariadb-10    — load into one container only
#############################################

set -e

# Load environment variables
source "$(dirname "$0")/load-env.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_URL="https://github.com/datacharmer/test_db.git"
TMP_DIR="/tmp/employees_test_db"

print_info()    { echo -e "${BLUE}i ${NC}$1"; }
print_success() { echo -e "${GREEN}v${NC} $1"; }
print_error()   { echo -e "${RED}x${NC} $1"; }
print_header() {
    echo ""
    echo -e "${YELLOW}======================================${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}======================================${NC}"
    echo ""
}

# Clone the test_db repo to a local temp dir
fetch_repo() {
    if [ -d "$TMP_DIR/.git" ]; then
        print_info "test_db repo already present at $TMP_DIR — pulling latest..."
        git -C "$TMP_DIR" pull --quiet
    else
        print_info "Cloning employees test_db repo..."
        git clone --quiet "$REPO_URL" "$TMP_DIR"
    fi
    print_success "test_db repo ready"
}

# Check container is running
check_container() {
    local container=$1
    if ! docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        print_error "Container $container is not running!"
        return 1
    fi
    print_success "Container $container is running"
    return 0
}

# Copy SQL files into the container and run the load
load_employees() {
    local container=$1
    local db_cmd=$2
    local root_password=$3

    print_info "Copying test_db files into $container..."
    docker exec "$container" mkdir -p /tmp/test_db
    docker cp "$TMP_DIR/." "$container:/tmp/test_db/"
    print_success "Files copied"

    print_info "Loading employees database into $container (this takes ~10-15s)..."
    docker exec -w /tmp/test_db "$container" \
        sh -c "$db_cmd -uroot -p\"$root_password\" < /tmp/test_db/employees.sql" 2>/dev/null
    print_success "employees database loaded"
}

# Grant app user access to the employees database
grant_access() {
    local container=$1
    local db_cmd=$2
    local root_password=$3
    local app_user

    app_user=$(docker exec "$container" printenv MYSQL_USER 2>/dev/null || true)
    if [ -z "$app_user" ]; then
        print_info "MYSQL_USER not set in $container — skipping grant"
        return 0
    fi

    print_info "Granting employees.* to '$app_user'@'%' in $container..."
    docker exec "$container" \
        $db_cmd -uroot -p"$root_password" \
        -e "GRANT ALL PRIVILEGES ON employees.* TO '$app_user'@'%'; FLUSH PRIVILEGES;" \
        2>/dev/null
    print_success "Access granted to $app_user"
}

# Verify record counts
verify_load() {
    local container=$1
    local db_cmd=$2
    local root_password=$3

    print_info "Verifying record counts in $container..."

    docker exec "$container" \
        $db_cmd -uroot -p"$root_password" employees \
        -e "SELECT table_name, table_rows
            FROM information_schema.tables
            WHERE table_schema = 'employees'
            ORDER BY table_name;" 2>/dev/null

    print_success "Verification done"
}

# Setup a single container
setup_container() {
    local container=$1
    local db_cmd=$2
    local root_password=$3

    print_header "Loading employees DB into $container"

    check_container  "$container"                            || return 1
    load_employees   "$container" "$db_cmd" "$root_password" || return 1
    grant_access     "$container" "$db_cmd" "$root_password" || return 1
    verify_load      "$container" "$db_cmd" "$root_password" || return 1

    print_success "Done: $container"
    echo ""
}

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

main() {
    local target="${1:-}"

    print_header "Employees Sample Database Setup"

    print_info "Source: $REPO_URL"
    print_info "Tables: employees, departments, dept_emp, dept_manager, titles, salaries"
    print_info "Size:   ~300k employees, ~2.8M salary rows"
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

    fetch_repo

    if [ -n "$target" ]; then
        read -r db_cmd root_pass <<< "$(get_container_args "$target")"
        setup_container "$target" "$db_cmd" "$root_pass"
    else
        setup_container "mariadb-10" "mysql"   "$MARIADB_10_ROOT_PASSWORD"
        setup_container "mariadb-11" "mariadb" "$MARIADB_11_ROOT_PASSWORD"
        setup_container "mariadb-12" "mariadb" "$MARIADB_12_ROOT_PASSWORD"
    fi

    print_header "Employees Database Ready!"

    echo "Connect and query:"
    echo ""
    echo "  source load-env.sh"
    echo "  docker exec -it mariadb-10 mysql -uroot -p\$MARIADB_10_ROOT_PASSWORD employees"
    echo ""
    echo "Sample queries:"
    echo "  SELECT COUNT(*) FROM employees;"
    echo "  SELECT * FROM departments;"
    echo "  SELECT e.first_name, e.last_name, s.salary"
    echo "    FROM employees e JOIN salaries s ON e.emp_no = s.emp_no"
    echo "    WHERE s.to_date = '9999-01-01' ORDER BY s.salary DESC LIMIT 10;"
    echo ""
}

main "$@"
