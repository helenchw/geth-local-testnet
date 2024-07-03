#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh
set -u +e

cleanup() {
    kill $(jobs -p) 2>/dev/null
}

trap cleanup EXIT

container_name=$CL_BOOTNODE_CONTAINER_NAME
log_file=${CONSENSUS_DIR_MOUNT_PATH}/bootnode.log

read_bootnode_node_list
node_ip=${bootnodes[0]}

# Start the boot node
echo "Started the lighthouse bootnode which is now listening at port $CL_BOOTNODE_PORT"

# --disable-packet-filter is necessary because it's involed in rate limiting and nodes per IP limit
# See https://github.com/sigp/discv5/blob/v0.1.0/src/socket/filter/mod.rs#L149-L186
ssh ${node_ip} docker run -d \
    -u ${BLOCKCHAIN_USER} \
    -v $CL_BOOTNODE_DIR:${BOOTNODE_DIR_MOUNT_PATH} \
    -p $CL_BOOTNODE_PORT:$CL_BOOTNODE_PORT/udp \
    -p $CL_BOOTNODE_PORT:$CL_BOOTNODE_PORT/tcp \
    -p 9000:9000/udp \
    -p 9000:9000/tcp \
    ${COMMON_NODE_CONTAINER_OPTIONS} \
    --name $container_name \
    ${LIGHTHOUSE_IMAGE}:${LIGHTHOUSE_IMAGE_TAG} \
    ${LIGHTHOUSE_CMD} boot_node \
    --testnet-dir ${BOOTNODE_DIR_MOUNT_PATH} \
    --port $CL_BOOTNODE_PORT \
	--disable-packet-filter \
    --listen-address 0.0.0.0 \
    --network-dir ${BOOTNODE_DIR_MOUNT_PATH} \
    --logfile ${log_file}

if test $? -ne 0; then
    node_error "The CL bootnode returns an error. The last 10 lines of the log file is shown below.\n\n$(ssh ${node_ip} docker logs -n 10 $container_name)"
    exit 1
fi

if [ $NO_SHUTDOWN -ne 1 ]; then
    ssh ${node_ip} docker wait $container_name
fi
