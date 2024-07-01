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
el_node_container_name $index
datadir=$el_data_dir
address=$(cat $datadir/address)
port=$(expr $BASE_EL_PORT + $index)
rpc_port=$(expr $BASE_EL_RPC_PORT + $index)
http_port=$(expr $BASE_EL_HTTP_PORT + $index)
log_file=${DATA_DIR_MOUNT_PATH}/geth.log

echo "Started the geth node #$index which is now listening at port $port and rpc at port $rpc_port. You can see the log at $log_file"
docker run -d \
    -u ${BLOCKCHAIN_USER} \
    -v $datadir:${DATA_DIR_MOUNT_PATH} \
    -v $ROOT/password:/password \
    -p $port:$port/udp \
    -p $port:$port/tcp \
    -p $rpc_port:$rpc_port \
    -p ${http_port}:${http_port} \
    --name ${container_name} \
    ${GETH_IMAGE}:${GETH_IMAGE_TAG} \
    ${GETH_CMD} \
    --datadir ${DATA_DIR_MOUNT_PATH} \
    --authrpc.addr 0.0.0.0 \
    --authrpc.vhosts '*' \
    --authrpc.port $rpc_port \
    --port $port \
    --bootnodes $boot_enode \
    --networkid $NETWORK_ID \
    --unlock $address \
    --allow-insecure-unlock \
    --password /password \
    --http \
    --http.port ${http_port} \
    --http.addr 0.0.0.0 \
    --nat extip:${MY_NODE_IP} \
    --log.file ${log_file} \
    --log.rotate

if test $? -ne 0; then
    node_error "The geth node #$index returns an error. The last 10 lines of the log file is shown below.\n\n$(docker logs -n 10 ${container_name})"
    exit 1
fi

docker wait ${container_name}
