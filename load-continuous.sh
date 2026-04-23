#!/bin/bash

#############################################
# Continuous Load Generator for QPM Binary Testing
#
# Runs four parallel load loops on a MariaDB container
# until the container stops or you press Ctrl+C:
#
#   1. slow-query loop   — complex SELECTs, JOINs, full-table scans
#   2. blocking loop     — rotating InnoDB lock contention
#   3. dml loop          — continuous INSERT / UPDATE / DELETE
#   4. wait-event loop   — bulk UPDATEs to trigger IO + lock waits
#
# Usage:
#   ./load-continuous.sh [container] [db_command] [root_password]
#
# Examples:
#   ./load-continuous.sh                           # defaults to mariadb-10
#   ./load-continuous.sh mariadb-11 mariadb $MARIADB_11_ROOT_PASSWORD
#   ./load-continuous.sh mariadb-12 mariadb $MARIADB_12_ROOT_PASSWORD
#############################################

set -e

source "$(dirname "$0")/load-env.sh"

# ── Configuration ───────────────────────────────────────────────────────────
CONTAINER="${1:-mariadb-10}"
DB_CMD="${2:-mysql}"
ROOT_PASS="${3:-$MARIADB_10_ROOT_PASSWORD}"

# How often each loop sleeps between iterations (seconds)
SLOW_QUERY_INTERVAL=3
BLOCKING_HOLD_SECONDS=90   # must be > nri-mysql poll interval (30s) with margin
BLOCKING_CYCLE_GAP=5       # gap between blocking cycles
DML_INTERVAL=1
WAIT_EVENT_INTERVAL=4

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ── Helpers ──────────────────────────────────────────────────────────────────
log()  { echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"; }
ok()   { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓${NC} $1"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠${NC} $1"; }
err()  { echo -e "${RED}[$(date '+%H:%M:%S')] ✗${NC} $1"; }

CHILD_PIDS=()

cleanup() {
    echo ""
    warn "Stopping all load loops..."
    for pid in "${CHILD_PIDS[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    # Kill any lingering docker exec processes spawned by subshells
    jobs -p | xargs -r kill 2>/dev/null || true
    ok "All loops stopped."
    exit 0
}
trap cleanup SIGINT SIGTERM

# Set DEBUG=1 to see SQL errors and connection failures in the terminal
DEBUG="${DEBUG:-0}"

# Returns 0 (true) while the container is running
container_up() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"
}

# Run SQL — errors visible when DEBUG=1, silenced otherwise
run_sql() {
    if [ "$DEBUG" = "1" ]; then
        docker exec -i "$CONTAINER" "$DB_CMD" -uroot -p"$ROOT_PASS" \
            --connect-timeout=5 "$@" 2>&1 || true
    else
        docker exec -i "$CONTAINER" "$DB_CMD" -uroot -p"$ROOT_PASS" \
            --connect-timeout=5 "$@" > /dev/null 2>&1 || true
    fi
}

# ── Init ─────────────────────────────────────────────────────────────────────
wait_for_container() {
    until container_up; do
        warn "Waiting for $CONTAINER to be running..."
        sleep 5
    done
    ok "$CONTAINER is up"
}

# ── Loop 1: Slow Queries ──────────────────────────────────────────────────────
# Cycles through 8 distinct query patterns so DIGEST stats keep growing.
slow_query_loop() {
    log "[slow-queries] Loop started"

    QUERIES=(
        "USE qpm_test; SELECT COUNT(*), AVG(data4) FROM large_table WHERE data1 LIKE '%Data%';"
        "USE qpm_test; SELECT c.first_name, c.last_name, COUNT(o.order_id) AS cnt, SUM(o.amount) AS total FROM customers c LEFT JOIN orders o ON c.customer_id = o.customer_id WHERE c.country = 'USA' GROUP BY c.customer_id, c.first_name, c.last_name HAVING total > 1000;"
        "USE qpm_test; SELECT * FROM orders WHERE amount > (SELECT AVG(amount) FROM orders) ORDER BY order_date DESC LIMIT 100;"
        "USE qpm_test; SELECT o.order_id, c.first_name, c.last_name, p.product_name, o.amount, o.status FROM orders o INNER JOIN customers c ON o.customer_id = c.customer_id INNER JOIN products p ON o.product_id = p.product_id WHERE o.order_date >= DATE_SUB(NOW(), INTERVAL 30 DAY) ORDER BY o.amount DESC;"
        "USE qpm_test; SELECT DATE(order_date) AS day, status, COUNT(*) AS cnt, SUM(amount) AS rev, AVG(amount) AS avg_val FROM orders GROUP BY DATE(order_date), status ORDER BY day DESC;"
        "USE qpm_test; SELECT * FROM large_table WHERE data2 LIKE '%consectetur%' ORDER BY created_at DESC LIMIT 100;"
        "USE qpm_test; SELECT p.category, COUNT(DISTINCT o.order_id) AS oc, COUNT(DISTINCT o.customer_id) AS cc, SUM(o.amount) AS rev FROM products p INNER JOIN orders o ON p.product_id = o.product_id GROUP BY p.category HAVING oc > 5;"
        "USE qpm_test; SELECT l1.id, l1.data1, COUNT(l2.id) AS related FROM large_table l1 LEFT JOIN large_table l2 ON l1.data3 = l2.data3 AND l1.id != l2.id WHERE l1.data3 BETWEEN 100 AND 200 GROUP BY l1.id, l1.data1 LIMIT 50;"
    )

    IDX=0
    COUNT=0
    while container_up; do
        run_sql -e "${QUERIES[$IDX]}"
        IDX=$(( (IDX + 1) % ${#QUERIES[@]} ))
        COUNT=$(( COUNT + 1 ))
        [ $(( COUNT % 8 )) -eq 0 ] && log "[slow-queries] ${COUNT} queries fired (cycle complete)"
        sleep "$SLOW_QUERY_INTERVAL"
    done

    warn "[slow-queries] Container stopped — loop exiting"
}

# ── Loop 2: Blocking Sessions ─────────────────────────────────────────────────
# Creates a blocker that holds a row lock for $BLOCKING_HOLD_SECONDS, then
# spawns two blocked sessions against the same row. Repeats continuously.
blocking_loop() {
    log "[blocking] Loop started"

    CYCLE=0
    while container_up; do
        CYCLE=$(( CYCLE + 1 ))
        log "[blocking] Cycle ${CYCLE} — blocker acquiring lock on account_id=1001 for ${BLOCKING_HOLD_SECONDS}s"

        # Blocker on account 1001
        docker exec -i "$CONTAINER" "$DB_CMD" -uroot -p"$ROOT_PASS" \
            --connect-timeout=5 <<EOF > /dev/null 2>&1 &
USE qpm_test;
SET autocommit=0;
START TRANSACTION;
UPDATE blocking_test SET balance = balance + 1 WHERE account_id = 1001;
SELECT SLEEP(${BLOCKING_HOLD_SECONDS});
ROLLBACK;
EOF
        BLOCKER_PID=$!

        # Give blocker time to acquire the lock
        sleep 3
        log "[blocking] Lock held — spawning blocked sessions"

        # Blocked session 1 — same account
        docker exec -i "$CONTAINER" "$DB_CMD" -uroot -p"$ROOT_PASS" \
            --connect-timeout=5 <<EOF > /dev/null 2>&1 &
USE qpm_test;
SET autocommit=0;
SET SESSION innodb_lock_wait_timeout=30;
START TRANSACTION;
UPDATE blocking_test SET balance = balance + 2 WHERE account_id = 1001;
COMMIT;
EOF

        # Blocked session 2 — same row, different amount (creates second waiter)
        docker exec -i "$CONTAINER" "$DB_CMD" -uroot -p"$ROOT_PASS" \
            --connect-timeout=5 <<EOF > /dev/null 2>&1 &
USE qpm_test;
SET autocommit=0;
SET SESSION innodb_lock_wait_timeout=100;
START TRANSACTION;
UPDATE blocking_test SET balance = balance + 3 WHERE account_id = 1001;
COMMIT;
EOF

        # Wait for blocker to release (holds for BLOCKING_HOLD_SECONDS)
        wait "$BLOCKER_PID" 2>/dev/null || true
        log "[blocking] Cycle ${CYCLE} done — sleeping ${BLOCKING_CYCLE_GAP}s before next cycle"

        sleep "$BLOCKING_CYCLE_GAP"
    done

    warn "[blocking] Container stopped — loop exiting"
}

# ── Loop 3: DML Load ──────────────────────────────────────────────────────────
# Keeps rows flowing: inserts new orders, updates random customers,
# deletes a small batch of old orders so the table doesn't grow unbounded.
dml_loop() {
    log "[dml] Loop started"

    COUNTER=1
    while container_up; do
        run_sql -e "
            USE qpm_test;
            INSERT INTO orders (customer_id, product_id, order_date, amount, status, notes)
            VALUES (
                FLOOR(RAND() * 1000) + 1,
                FLOOR(RAND() * 500)  + 1,
                NOW(),
                ROUND(RAND() * 1000 + 20, 2),
                ELT(FLOOR(RAND()*4)+1, 'pending','processing','shipped','delivered'),
                CONCAT('load-test-order-', $COUNTER)
            );
            UPDATE customers
               SET city = ELT(FLOOR(RAND()*5)+1,'New York','London','Tokyo','Paris','Berlin')
             WHERE customer_id = FLOOR(RAND() * 1000) + 1;
            DELETE FROM orders
             WHERE order_id IN (
                 SELECT order_id FROM (
                     SELECT order_id FROM orders
                      ORDER BY order_id ASC
                      LIMIT 3
                 ) AS t
             );
        "
        COUNTER=$((COUNTER + 1))
        sleep "$DML_INTERVAL"
    done

    warn "[dml] Container stopped — loop exiting"
}

# ── Loop 4: Wait Event Load ───────────────────────────────────────────────────
# Bulk UPDATEs across many rows to generate InnoDB IO and lock wait events
# that show up in events_waits_current / events_waits_history.
wait_event_loop() {
    log "[wait-events] Loop started"

    while container_up; do
        run_sql -e "
            USE qpm_test;
            UPDATE large_table SET data4 = data4 * 1.001 WHERE data3 < 50;
            UPDATE large_table SET data4 = data4 * 0.999 WHERE data3 > 950;
            UPDATE large_table SET updated_at = NOW()    WHERE data3 BETWEEN 400 AND 600 LIMIT 200;
        "
        sleep "$WAIT_EVENT_INTERVAL"
    done

    warn "[wait-events] Container stopped — loop exiting"
}

# ── Status Reporter ───────────────────────────────────────────────────────────
# Prints a live counter line every 30 seconds so you know it's still running.
status_loop() {
    START_TIME=$SECONDS
    while container_up; do
        ELAPSED=$(( SECONDS - START_TIME ))
        MINS=$(( ELAPSED / 60 ))
        SECS=$(( ELAPSED % 60 ))
        echo -e "${CYAN}[$(date '+%H:%M:%S')] Running ${MINS}m${SECS}s on ${CONTAINER} — slow-queries + blocking + dml + wait-events active${NC}"
        sleep 30
    done
    warn "[status] Container stopped"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${YELLOW}================================================${NC}"
    echo -e "${YELLOW}  Continuous QPM Load Generator${NC}"
    echo -e "${YELLOW}================================================${NC}"
    echo -e "  Container : ${CYAN}$CONTAINER${NC}"
    echo -e "  DB client : ${CYAN}$DB_CMD${NC}"
    echo -e "  Loops     : slow-queries | blocking | dml | wait-events"
    echo -e "  Stops when: container goes down  or  Ctrl+C"
    echo -e "${YELLOW}================================================${NC}"
    echo ""

    wait_for_container

    echo ""
    log "Starting all load loops..."
    echo ""

    slow_query_loop  & CHILD_PIDS+=($!)
    blocking_loop    & CHILD_PIDS+=($!)
    dml_loop         & CHILD_PIDS+=($!)
    wait_event_loop  & CHILD_PIDS+=($!)
    status_loop      & CHILD_PIDS+=($!)

    # Wait until all child loops exit (they exit when container_up returns false)
    wait
    ok "All loops finished — $CONTAINER is no longer running."
}

main
