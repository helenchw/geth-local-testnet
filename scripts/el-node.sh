#!/usr/bin/env bash

source ./scripts/util.sh
set -u +e

cleanup() {
    kill $(jobs -p) 2>/dev/null
}

trap cleanup EXIT

index=$1
boot_enode=$2

el_data_dir $index
datadir=$el_data_dir
address=$(cat $datadir/address)
port=$(expr $BASE_GETH_PORT + $index)
rpc_port=$(expr $BASE_GETH_RPC_PORT + $index)
log_file=$datadir/geth.log

echo "Started the geth node #$index which is now listening at port $port"
geth \
    --datadir $datadir \
    --authrpc.port $rpc_port \
    --port $port \
    --bootnodes $boot_enode \
    --networkid $NETWORK_ID \
    --unlock $address \
    --password $ROOT/password \
    > $log_file 2>&1

if test $? -ne 0; then
    node_error "The geth node #$index returns an error. Please look at $log_file more detail."
    exit 1
fi