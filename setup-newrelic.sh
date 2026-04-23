#!/bin/bash

#############################################
# New Relic Setup Script for MariaDB Containers
# This script automates the installation and configuration
# of New Relic Infrastructure agent and MySQL integration
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

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_header() {
    echo ""
    echo -e "${YELLOW}======================================${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}======================================${NC}"
    echo ""
}

# Check if license key is provided
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

# Check if container is running
check_container() {
    local container=$1
    if ! docker ps | grep -q "$container"; then
        print_error "Container $container is not running!"
        return 1
    fi
    print_success "Container $container is running"
    return 0
}

# Install New Relic Infrastructure agent in a container
install_infra_agent() {
    local container=$1
    local display_name=$2
    
    print_info "Installing Infrastructure agent in $container..."
    
    # Update and install dependencies
    docker exec $container bash -c "
        apt-get update -qq && \
        apt-get install -y -qq curl gnupg apt-transport-https ca-certificates procps > /dev/null 2>&1
    " || {
        print_error "Failed to install dependencies"
        return 1
    }
    
    # Add New Relic repository
    docker exec $container bash -c "
        curl -s https://download.newrelic.com/infrastructure_agent/gpg/newrelic-infra.gpg | apt-key add - && \
        echo 'deb https://download.newrelic.com/infrastructure_agent/linux/apt jammy main' > /etc/apt/sources.list.d/newrelic-infra.list
    " || {
        print_error "Failed to add New Relic repository"
        return 1
    }
    
    # Install Infrastructure agent
    docker exec $container bash -c "
        apt-get update -qq && \
        apt-get install -y -qq newrelic-infra > /dev/null 2>&1
    " || {
        print_error "Failed to install Infrastructure agent"
        return 1
    }
    
    # Configure the agent
    docker exec $container bash -c "cat > /etc/newrelic-infra.yml << EOF
license_key: ${NEW_RELIC_LICENSE_KEY}
display_name: ${display_name}
log_level: info
EOF
    " || {
        print_error "Failed to configure Infrastructure agent"
        return 1
    }
    
    print_success "Infrastructure agent installed in $container"
    return 0
}

# Install MySQL integration
install_mysql_integration() {
    local container=$1
    
    print_info "Installing MySQL integration in $container..."
    
    docker exec $container bash -c "
        apt-get install -y -qq nri-mysql > /dev/null 2>&1 && \
        mkdir -p /etc/newrelic-infra/integrations.d
    " || {
        print_error "Failed to install MySQL integration"
        return 1
    }
    
    print_success "MySQL integration installed in $container"
    return 0
}

# Create monitoring user in database
create_monitoring_user() {
    local container=$1
    local db_command=$2
    local root_password=$3
    
    print_info "Creating monitoring user in $container..."
    
    docker exec $container $db_command -uroot -p$root_password -e "
        CREATE USER IF NOT EXISTS '${NEWRELIC_DB_USER}'@'localhost' IDENTIFIED BY '${NEWRELIC_DB_PASSWORD}';
        GRANT REPLICATION CLIENT ON *.* TO '${NEWRELIC_DB_USER}'@'localhost';
        GRANT SELECT ON *.* TO '${NEWRELIC_DB_USER}'@'localhost';
        FLUSH PRIVILEGES;
    " 2>/dev/null || {
        print_error "Failed to create monitoring user"
        return 1
    }
    
    print_success "Monitoring user created in $container"
    return 0
}

# Verify monitoring user connection
verify_user_connection() {
    local container=$1
    local db_command=$2
    
    print_info "Verifying monitoring user connection in $container..."
    
    if docker exec $container $db_command -u${NEWRELIC_DB_USER} -p${NEWRELIC_DB_PASSWORD} -e "SELECT 1;" > /dev/null 2>&1; then
        print_success "Monitoring user connection verified"
        return 0
    else
        print_error "Failed to verify monitoring user connection"
        return 1
    fi
}

# Create MySQL integration configuration
create_mysql_config() {
    local container=$1
    local version=$2
    
    print_info "Creating MySQL integration config in $container..."
    
    docker exec $container bash -c "cat > /etc/newrelic-infra/integrations.d/mysql-config.yml << 'EOF'
integrations:
  - name: nri-mysql
    env:
      HOSTNAME: localhost
      PORT: 3306
      USERNAME: ${NEWRELIC_DB_USER}
      PASSWORD: ${NEWRELIC_DB_PASSWORD}
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
      version: '${version}'
    inventory_source: config/mysql
EOF
    " || {
        print_error "Failed to create MySQL config"
        return 1
    }
    
    print_success "MySQL integration config created"
    return 0
}

# Start New Relic Infrastructure agent
start_infra_agent() {
    local container=$1
    
    print_info "Starting Infrastructure agent in $container..."
    
    # Start the agent
    docker exec $container bash -c "
        service newrelic-infra start > /dev/null 2>&1 || \
        /usr/bin/newrelic-infra -config /etc/newrelic-infra.yml > /dev/null 2>&1 &
    " || {
        print_warning "Agent may already be running or needs manual start"
    }
    
    # Wait a moment for agent to start
    sleep 2
    
    # Check if agent is running
    if docker exec $container bash -c "ps aux | grep -v grep | grep newrelic-infra > /dev/null 2>&1"; then
        print_success "Infrastructure agent is running"
        return 0
    else
        print_warning "Could not verify agent status (this may be normal)"
        return 0
    fi
}

# Verify integration is working
verify_integration() {
    local container=$1
    
    print_info "Verifying MySQL integration in $container..."
    
    # Check if integration binary exists and can run
    docker exec $container bash -c "
        /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql \
            -hostname localhost \
            -port 3306 \
            -username ${NEWRELIC_DB_USER} \
            -password ${NEWRELIC_DB_PASSWORD} \
            -metrics 2>&1 | grep -q 'integration_name'
    " || {
        print_warning "Integration verification incomplete (check logs later)"
        return 0
    }
    
    print_success "MySQL integration verified"
    return 0
}

# Setup a single container
setup_container() {
    local container=$1
    local version=$2
    local db_command=$3
    local root_password=$4
    
    print_header "Setting up $container (MariaDB $version)"
    
    # Check if container is running
    if ! check_container "$container"; then
        print_error "Skipping $container - container not running"
        return 1
    fi
    
    # Install Infrastructure agent
    install_infra_agent "$container" "$container" || return 1
    
    # Install MySQL integration
    install_mysql_integration "$container" || return 1
    
    # Create monitoring user
    create_monitoring_user "$container" "$db_command" "$root_password" || return 1
    
    # Verify user connection
    verify_user_connection "$container" "$db_command" || return 1
    
    # Create MySQL integration config
    create_mysql_config "$container" "$version" || return 1
    
    # Start Infrastructure agent
    start_infra_agent "$container" || return 1
    
    # Verify integration
    verify_integration "$container"
    
    print_success "Setup completed for $container"
    echo ""
    
    return 0
}

# Main setup function
main() {
    print_header "New Relic Setup for MariaDB Containers"
    
    # Check license key
    check_license_key
    
    echo ""
    print_info "This script will:"
    echo "  1. Install New Relic Infrastructure agent"
    echo "  2. Install MySQL/MariaDB integration"
    echo "  3. Create monitoring user: ${NEWRELIC_DB_USER}"
    echo "  4. Configure integrations"
    echo "  5. Start monitoring"
    echo ""
    
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Setup cancelled"
        exit 0
    fi
    
    # Setup each container
    setup_container "mariadb-10" "10" "mysql" "$MARIADB_10_ROOT_PASSWORD"
    setup_container "mariadb-11" "11" "mariadb" "$MARIADB_11_ROOT_PASSWORD"
    setup_container "mariadb-12" "12" "mariadb" "$MARIADB_12_ROOT_PASSWORD"
    
    # Final summary
    print_header "Setup Complete!"
    
    echo "Next steps:"
    echo ""
    echo "1. Check agent status:"
    echo "   docker exec mariadb-10 ps aux | grep newrelic-infra"
    echo ""
    echo "2. View agent logs:"
    echo "   docker exec mariadb-10 tail -f /var/log/newrelic-infra/newrelic-infra.log"
    echo ""
    echo "3. Test integration manually:"
    echo "   docker exec mariadb-10 /var/db/newrelic-infra/newrelic-integrations/bin/nri-mysql \\"
    echo "     -hostname localhost -port 3306 \\"
    echo "     -username ${NEWRELIC_DB_USER} -password ${NEWRELIC_DB_PASSWORD} \\"
    echo "     -metrics"
    echo ""
    echo "4. Check New Relic UI (wait 2-3 minutes for data):"
    echo "   - Infrastructure > Hosts (look for mariadb-10, mariadb-11, mariadb-12)"
    echo "   - Infrastructure > Integrations > MySQL"
    echo ""
    print_info "Note: If containers are recreated, you'll need to run this script again"
    echo ""
}

# Run main function
main
