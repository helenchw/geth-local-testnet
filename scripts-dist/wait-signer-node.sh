#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh
set -u +e

read_signer_node_list
node_ip=${signer_nodes[0]}

# Wait until the signer node starts the IPC socket
ssh ${signer_nodes} "while ! test -S $SIGNER_EL_DATADIR/geth.ipc; do sleep 1; done"

