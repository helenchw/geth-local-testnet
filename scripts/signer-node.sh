#!/usr/bin/env bash

source ./scripts/util.sh
set -u +e

cleanup() {
    kill $(jobs -p) 2>/dev/null
}

trap cleanup EXIT

datadir=$1
boot_enode=$2

address=$(cat $datadir/address)
log_file=$datadir/geth.log
port=$SIGNER_PORT
rpc_port=$SIGNER_RPC_PORT
http_port=$SIGNER_HTTP_PORT
container_name=${SIGNER_NODE_CONTAIN_NAME}

echo "Started the geth node 'signer' which is now listening at port $SIGNER_PORT. You can see the log at $log_file"
docker run -d \
    -u ${BLOCKCHAIN_USER} \
    -v $datadir:${DATA_DIR_MOUNT_PATH} \
    -v $ROOT/password:/password \
    -p $port:$port/udp \
    -p $port:$port/tcp \
    -p $http_port:$http_port \
    -p $rpc_port:$rpc_port \
    ${COMMON_NODE_CONTAINER_OPTIONS} \
    --name $container_name \
    ${GETH_IMAGE}:${GETH_IMAGE_TAG} \
    ${GETH_CMD} \
    --datadir ${DATA_DIR_MOUNT_PATH} \
    --nat extip:${MY_NODE_IP} \
    --authrpc.addr 0.0.0.0 \
    --authrpc.port ${rpc_port} \
    --port $port \
    --http \
    --http.addr 0.0.0.0 \
    --http.port ${http_port} \
    --allow-insecure-unlock \
    --bootnodes $boot_enode \
    --networkid $NETWORK_ID \
    --unlock $address \
    --password /password \
    --mine \
    --miner.etherbase ${address} \
    --log.file ${DATA_DIR_MOUNT_PATH}/geth.log \
    --log.rotate

if test $? -ne 0; then
    node_error "The geth node 'signer' returns an error. The last 10 lines of the log file is shown below.\n\n$(docker logs -n 10 $container_name)"
    exit 1
fi

docker wait $container_name
