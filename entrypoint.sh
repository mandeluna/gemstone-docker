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
    echo "Warning: Lock file found. Attempting to clear stale locks..."
    # Optional: rm "$DATA_DIR/gs64stone.conf"
fi

# --- 4. Start NetLDI
echo "--- Starting NetLDI ---"
# NetLDI listens on port 50378 by default.
# We run it in the background (daemon mode is default for startnetldi).
gosu gemstone startnetldi

# --- 5. Start the Stone ---
# Switch to 'gemstone' user, start the stone with -z flag, and tail the log
exec gosu gemstone bash -c "startstone -z $CONFIG_FILE $GEMSTONE_NAME && tail -f $DATA_DIR/${GEMSTONE_NAME}.log"
