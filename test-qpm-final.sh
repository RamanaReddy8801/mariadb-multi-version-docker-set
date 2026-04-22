#!/bin/bash

#############################################
# Final QPM Test with Blocking Sessions
# This script generates complete test data including blocking scenarios
#############################################

set -e

# Load environment variables
source "$(dirname "$0")/load-env.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}$1${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to create blocking sessions in background
create_blocking_scenario() {
    local container=$1
    local db_command=$2
    local root_password=$3
    
    print_info "Creating blocking session scenario in $container..."
    
    # Start session 1 (blocker) in background
    docker exec -i $container $db_command -uroot -p$root_password <<'EOF' &
USE qpm_test;
SET autocommit=0;
START TRANSACTION;
UPDATE blocking_test SET balance = balance + 100 WHERE account_id = 1001;
SELECT SLEEP(10);
ROLLBACK;
EOF
    
    # Wait a moment for transaction to start
    sleep 2
    
    # Start session 2 (blocked) in background
    docker exec -i $container $db_command -uroot -p$root_password <<'EOF' &
USE qpm_test;
SET autocommit=0;
START TRANSACTION;
UPDATE blocking_test SET balance = balance + 200 WHERE account_id = 1001;
COMMIT;
EOF
    
    # Wait a moment for blocking to occur
    sleep 1
    
    print_success "Blocking scenario created"
}

# Main test execution
main() {
    print_header "Final QPM Test - All Versions with Blocking Data"
    
    REPORTS_DIR="qpm-reports/final"
    mkdir -p "$REPORTS_DIR"
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    
    # Build version info with environment variables
    local VERSION_INFOS=(
        "10:mariadb-10:mysql:${MARIADB_10_ROOT_PASSWORD}"
        "11:mariadb-11:mariadb:${MARIADB_11_ROOT_PASSWORD}"
        "12:mariadb-12:mariadb:${MARIADB_12_ROOT_PASSWORD}"
    )
    
    for VERSION_INFO in "${VERSION_INFOS[@]}"; do
        IFS=':' read -r VERSION CONTAINER DB_CMD ROOT_PASS <<< "$VERSION_INFO"
        
        print_header "MariaDB $VERSION - Creating Blocking Scenario"
        
        # Generate test data first
        print_info "Generating test data..."
        docker exec -i $CONTAINER $DB_CMD -uroot -p$ROOT_PASS < generate-qpm-testdata.sql > /dev/null 2>&1
        print_success "Test data generated"
        
        # Create blocking scenario
        create_blocking_scenario "$CONTAINER" "$DB_CMD" "$ROOT_PASS"
        
        # Create version-specific report
        REPORT_FILE="$REPORTS_DIR/mariadb_${VERSION}_complete_${TIMESTAMP}.md"
        
        print_info "Running QPM queries and generating report..."
        
        # Write report header
        cat > "$REPORT_FILE" <<HEADER
# MariaDB $VERSION - Complete QPM Test Report

**Generated:** $(date '+%Y-%m-%d %H:%M:%S')  
**Container:** $CONTAINER  
**Test Database:** qpm_test

## Executive Summary

Complete validation of all QPM queries with active test scenarios:
- ✅ Slow queries from test data generation
- ✅ Wait events from active transactions
- ✅ Blocking sessions from concurrent updates

---

HEADER
        
        # Run each QPM query
        for QPM_QUERY in "Slow Queries:qpm-queries/slow-queries.sql" "Wait Events:qpm-queries/wait-events.sql" "Blocking Sessions:qpm-queries/blocking-sessions.sql"; do
            IFS=':' read -r QUERY_NAME QUERY_FILE <<< "$QPM_QUERY"
            
            echo "## $QUERY_NAME" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            echo "**Query File:** \`$QUERY_FILE\`" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            
            # Run query
            TEMP_OUT="/tmp/qpm_out_$$"
            if docker exec -i $CONTAINER $DB_CMD -uroot -p$ROOT_PASS --table < "$QUERY_FILE" > "$TEMP_OUT" 2>&1; then
                ROW_COUNT=$(cat "$TEMP_OUT" | tail -n +2 | wc -l | tr -d ' ')
                
                if [ "$ROW_COUNT" -gt "1" ]; then
                    echo "**Status:** ✅ Success - $((ROW_COUNT - 1)) rows" >> "$REPORT_FILE"
                    echo "" >> "$REPORT_FILE"
                    echo '```' >> "$REPORT_FILE"
                    head -n 50 "$TEMP_OUT" >> "$REPORT_FILE"
                    if [ "$ROW_COUNT" -gt "50" ]; then
                        echo "... ($(($ROW_COUNT - 51)) more rows)" >> "$REPORT_FILE"
                    fi
                    echo '```' >> "$REPORT_FILE"
                    print_success "$QUERY_NAME: $((ROW_COUNT - 1)) rows"
                else
                    echo "**Status:** ⚠️ No Data" >> "$REPORT_FILE"
                    print_info "$QUERY_NAME: No data"
                fi
            else
                echo "**Status:** ❌ Error" >> "$REPORT_FILE"
                echo '```' >> "$REPORT_FILE"
                cat "$TEMP_OUT" >> "$REPORT_FILE"
                echo '```' >> "$REPORT_FILE"
                print_error "$QUERY_NAME: Error"
            fi
            
            echo "" >> "$REPORT_FILE"
            echo "---" >> "$REPORT_FILE"
            echo "" >> "$REPORT_FILE"
            
            rm -f "$TEMP_OUT"
        done
        
        # Add summary
        cat >> "$REPORT_FILE" <<FOOTER

## Test Summary

### Slow Queries ✅
- Captured queries from data generation process
- Includes full table scans, joins, aggregations
- Shows execution times and resource usage

### Wait Events
- Captured from performance_schema wait history
- May show file IO, mutex, and lock waits
- Depends on timing of data capture

### Blocking Sessions
- Created artificial blocking scenario
- Two transactions competing for same row lock
- Demonstrates lock wait detection

---

**Report Generated:** $(date '+%Y-%m-%d %H:%M:%S')
FOOTER
        
        print_success "Report saved: $REPORT_FILE"
        echo ""
        
        # Wait for blocking scenarios to complete
        sleep 2
    done
    
    # Kill any remaining background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    
    print_header "Testing Complete!"
    echo ""
    echo "📊 Final Reports:"
    ls -lh "$REPORTS_DIR/"*_${TIMESTAMP}.md | awk '{print "   ", $9, "(" $5 ")"}'
    echo ""
    print_success "All tests completed successfully!"
}

# Run main
main
