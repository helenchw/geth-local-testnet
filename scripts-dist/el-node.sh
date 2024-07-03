#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh
set -u +e


cleanup() {
    kill $(jobs -p) 2>/dev/null
}

trap cleanup EXIT

node_ip=$1
boot_enode=$2
address=$3

el_remote_data_dir
el_node_container_name
datadir=$el_remote_data_dir
port=$(expr $BASE_EL_PORT)
rpc_port=$(expr $BASE_EL_RPC_PORT)
http_port=$(expr $BASE_EL_HTTP_PORT)
log_file=${DATA_DIR_MOUNT_PATH}/geth.log

echo "Started the geth node at $node_ip which is now listening at port $port and rpc at port $rpc_port. You can see the log at $log_file"
ssh $node_ip docker run -d \
    -u ${BLOCKCHAIN_USER} \
    -v $datadir:${DATA_DIR_MOUNT_PATH} \
    -v $ROOT/password:/password \
    -p $port:$port/udp \
    -p $port:$port/tcp \
    -p $rpc_port:$rpc_port \
    -p ${http_port}:${http_port} \
    ${COMMON_NODE_CONTAINER_OPTIONS} \
    --name ${container_name} \
    ${GETH_IMAGE}:${GETH_IMAGE_TAG} \
    ${GETH_CMD} \
    --datadir ${DATA_DIR_MOUNT_PATH} \
    --authrpc.addr 0.0.0.0 \
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
    --nat extip:${node_ip} \
    --log.file ${log_file} \
    --log.rotate

if test $? -ne 0; then
    node_error "The geth node $node_ip returns an error. The last 10 lines of the log file is shown below.\n\n$(ssh ${node_ip} docker logs -n 10 ${container_name})"
    exit 1
fi

if [ $NO_SHUTDOWN -ne 1 ]; then
    ssh ${node_ip} docker wait ${container_name}
fi
