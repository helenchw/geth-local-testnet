#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh
set -u +e

cleanup() {
    kill $(jobs -p) 2>/dev/null
}

trap cleanup EXIT

datadir=$SIGNER_EL_DATADIR
boot_enode=$1

read_signer_node_list
node_ip=${signer_nodes[0]}

address=$(cat $datadir/address)
log_file=$datadir/geth.log
port=$SIGNER_PORT
rpc_port=$SIGNER_RPC_PORT
http_port=$SIGNER_HTTP_PORT
container_name=${SIGNER_NODE_CONTAIN_NAME}

echo "Started the geth node 'signer' which is now listening at port $SIGNER_PORT. You can see the log at $log_file"
ssh ${node_ip} docker run -d \
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
    --nat extip:${node_ip} \
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
    node_error "The geth node 'signer' returns an error. The last 10 lines of the log file is shown below.\n\n$(ssh ${node_ip} docker logs -n 10 $container_name)"
    exit 1
fi

if [ $NO_SHUTDOWN -ne 1 ]; then
    ssh ${node_ip} docker wait $container_name
fi
