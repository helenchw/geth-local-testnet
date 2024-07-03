#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh
set -u +e

cleanup() {
    kill $(jobs -p) 2>/dev/null
}

trap cleanup EXIT

container_name=${EL_BOOTNODE_CONTAINER_NAME}

# Start the boot node
bootnode_port=30305
echo "Started the geth bootnode which is now listening at :$bootnode_port"
docker run -d \
    -u ${BLOCKCHAIN_USER} \
    -v $EL_BOOT_KEY_FILE:/boot.key \
    -w / \
    -p ${bootnode_port}:${bootnode_port}/udp \
    -p ${bootnode_port}:${bootnode_port}/tcp \
    -p 8545:8545 \
    ${COMMON_NODE_CONTAINER_OPTIONS} \
    --name $container_name \
    ${GETH_IMAGE}:${GETH_IMAGE_TAG} \
    ${GETH_BOOTNODE_CMD} \
    -nodekey boot.key \
    -addr 0.0.0.0:$bootnode_port

if test $? -ne 0; then
    node_error "The EL bootnode returns an error. The last 10 lines of the log file is shown below.\n\n$(docker logs -n 10 $container_name)"
    exit 1
fi

docker wait $container_name
