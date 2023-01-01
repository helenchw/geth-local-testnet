#!/usr/bin/env bash

source ./scripts/util.sh
set -u +e

cleanup() {
    kill $(jobs -p) 2>/dev/null
}

trap cleanup EXIT

# Start the boot node
bootnode_port=30305
echo "Started the geth bootnode which is now listening at :$bootnode_port"
bootnode \
    -nodekey $BOOT_KEY_FILE \
    -addr :$bootnode_port \
    < /dev/null > $BOOT_LOG_FILE 2>&1

if test $? -ne 0; then
    node_error "The bootnode returns an error. Please look at $BOOT_LOG_FILE for more detail."
    exit 1
fi