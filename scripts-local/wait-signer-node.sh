#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh
set -u +e

# Wait until the signer node starts the IPC socket
while ! test -S $SIGNER_EL_DATADIR/geth.ipc; do
    sleep 1
done

