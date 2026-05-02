#!/bin/bash
set -e

# Define paths
DATA_DIR="/opt/gemstone/data"
LOCK_DIR="/opt/gemstone/locks"
LOG_DIR="/opt/gemstone/log"
EXTENT_FILE="$DATA_DIR/extent0.dbf"
SOURCE_EXTENT="$GEMSTONE/bin/extent0.dbf"
CONFIG_FILE="$DATA_DIR/system.conf"

# --- 1. Fix Permissions (Running as Root) ---
# Ensure the 'gemstone' user owns the mounted volume and lock directory
echo "--- Fixing permissions on $DATA_DIR and $LOCK_DIR ---"
chown -R gemstone:gemstone "$DATA_DIR"
chown -R gemstone:gemstone "$LOCK_DIR"
chmod 755 "$LOCK_DIR"

# Create and Fix Permissions
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
fi
chown -R gemstone:gemstone "$LOG_DIR"

# --- 2. Initialize Database (Running as gemstone via gosu) ---
if [ ! -f "$EXTENT_FILE" ]; then
    echo "--- Initializing new GemStone extent ---"
    
    # Copy the template extent using GemStone utility
    gosu gemstone copydbf "$SOURCE_EXTENT" "$EXTENT_FILE"
    gosu gemstone chmod 600 "$EXTENT_FILE"
    
    # Copy the default config file
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "--- Copying default system.conf ---"
        gosu gemstone cp "$GEMSTONE/data/system.conf" "$CONFIG_FILE"
        gosu gemstone chmod 644 "$CONFIG_FILE"
    fi
else
    echo "--- Existing extent found. Skipping initialization. ---"
fi

# --- 3. Cleanup Stale Locks ---
if [ -f "$DATA_DIR/gs64stone.conf" ]; then
    echo "Warning: Stale stone lock found. Removing..."
    rm -f "$DATA_DIR/gs64stone.conf"
fi

# --- 4. Start NetLDI
echo "--- Starting NetLDI ---"
# Stop any stale NetLDI from a previous container run. Docker restart reuses the
# container's writable layer, so lock files in $LOCK_DIR survive across restarts,
# causing startnetldi to report "already running" against a dead process.
gosu gemstone stopnetldi gs64ldi 2>/dev/null || true
rm -f "$LOCK_DIR"/gs64ldi* 2>/dev/null || true
gosu gemstone startnetldi -P 10500 -g

# --- 5. Start the Stone ---
# Stop any stale stone and remove its lock file. Like NetLDI, the stone's lock
# file in $LOCK_DIR survives Docker restarts (writable layer is reused), causing
# startstone to report "already exists but is not responding" against a dead process.
gosu gemstone stopstone "$GEMSTONE_NAME" 2>/dev/null || true
rm -f "$LOCK_DIR"/${GEMSTONE_NAME}* 2>/dev/null || true

# Switch to 'gemstone' user, start the stone with -z flag, and tail the log
exec gosu gemstone bash -c "startstone -z $CONFIG_FILE $GEMSTONE_NAME && tail -f $DATA_DIR/${GEMSTONE_NAME}.log"
