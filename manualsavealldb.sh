#!/bin/bash
################################################################################
# Redis Manual Save All Databases
################################################################################
# Location: /home/administrator/projects/redis/manualsavealldb.sh
#
# Purpose: Forces Redis to perform synchronous save (SAVE) to disk
# This ensures all data in memory is persisted before backup.
#
# Called by: backup scripts before creating tar archives
################################################################################

set -e

echo "=== Redis: Forcing synchronous save to disk ==="

# Check if Redis password is in secrets file
if [ -f /home/administrator/secrets/redis.env ]; then
    source /home/administrator/secrets/redis.env 2>/dev/null
fi

# Check if password is set
if [ -z "$REDIS_PASSWORD" ]; then
    # Try from config file
    REDIS_PASSWORD=$(grep "^requirepass" /home/administrator/projects/redis/config/redis.conf 2>/dev/null | awk '{print $2}')
fi

if [ -z "$REDIS_PASSWORD" ]; then
    echo "ERROR: Could not find Redis password"
    exit 1
fi

echo "Using authenticated connection"

# Get current info
echo "Checking Redis status..."
docker exec redis redis-cli -a "$REDIS_PASSWORD" --no-auth-warning INFO persistence | grep -E "rdb_last_save_time|rdb_changes_since_last_save"

# Perform synchronous save (blocks until complete)
echo ""
echo "Running SAVE command (this will block Redis until complete)..."
docker exec redis redis-cli -a "$REDIS_PASSWORD" --no-auth-warning SAVE

if [ $? -eq 0 ]; then
    echo "✓ Redis SAVE completed successfully"

    # Show updated info
    echo "  Updated status:"
    docker exec redis redis-cli -a "$REDIS_PASSWORD" --no-auth-warning INFO persistence | grep -E "rdb_last_save_time|rdb_changes_since_last_save"
    echo "  All in-memory data has been written to dump.rdb"
else
    echo "✗ Redis SAVE failed"
    exit 1
fi

echo ""
echo "=== Redis save operation complete ==="
