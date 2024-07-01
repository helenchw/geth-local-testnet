#!/usr/bin/env bash

source ./scripts/util.sh
set -u +e

cleanup() {
    kill $(jobs -p) 2>/dev/null
}

trap cleanup EXIT

index=$1

cl_data_dir $index
cl_vc_container_name $index
datadir=$cl_data_dir
log_file=${DATA_DIR_MOUNT_PATH}/validator_client.log

echo "Started the lighthouse validator client #$index. You can see the log at $log_file"

# Send all the fee to the PoA signer
docker run -d \
    -u ${BLOCKCHAIN_USER} \
    -v $datadir:${DATA_DIR_MOUNT_PATH} \
    -v $CONSENSUS_DIR:${CONSENSUS_DIR_MOUNT_PATH} \
    ${COMMON_NODE_CONTAINER_OPTIONS} \
    --name ${container_name} \
    ${LIGHTHOUSE_IMAGE}:${LIGHTHOUSE_IMAGE_TAG} \
    $LIGHTHOUSE_CMD validator_client \
    --datadir ${DATA_DIR_MOUNT_PATH} \
	--testnet-dir ${CONSENSUS_DIR_MOUNT_PATH} \
	--init-slashing-protection \
    --beacon-nodes http://${MY_NODE_IP}:$(expr $BASE_CL_HTTP_PORT + $index) \
    --suggested-fee-recipient $(cat $SIGNER_EL_DATADIR/address) \
    --logfile $log_file

if test $? -ne 0; then
    node_error "The lighthouse validator client #$index returns an error. The last 10 lines of the log file is shown below.\n\n$(docker logs -n 10 $container_name)"
    exit 1
fi

docker wait $container_name
