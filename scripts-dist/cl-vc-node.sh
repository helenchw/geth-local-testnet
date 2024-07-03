#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh

set -u +e

cleanup() {
    kill $(jobs -p) 2>/dev/null
}

trap cleanup EXIT

node_ip=$1

cl_remote_data_dir
cl_vc_container_name
datadir=$cl_remote_data_dir
log_file=${DATA_DIR_MOUNT_PATH}/validator_client.log
address=$(cat $SIGNER_EL_DATADIR/address)
bootnode_enr=$(cat $CL_BOOTNODE_DIR/enr.dat)

echo "Started the lighthouse validator client at $node_ip. You can see the log at $log_file"

# Send all the fee to the PoA signer
ssh ${node_ip} docker run -d \
    -u ${BLOCKCHAIN_USER} \
    -v $datadir:${DATA_DIR_MOUNT_PATH} \
    ${COMMON_NODE_CONTAINER_OPTIONS} \
    --name ${container_name} \
    ${LIGHTHOUSE_IMAGE}:${LIGHTHOUSE_IMAGE_TAG} \
    $LIGHTHOUSE_CMD validator_client \
	--testnet-dir ${DATA_DIR_MOUNT_PATH} \
    --datadir ${DATA_DIR_MOUNT_PATH} \
	--init-slashing-protection \
    --beacon-nodes http://${node_ip}:$(expr $BASE_CL_HTTP_PORT) \
    --suggested-fee-recipient $address \
    --logfile $log_file \
    --logfile-debug-level "info"

if test $? -ne 0; then
    node_error "The lighthouse validator client $node_ip returns an error. The last 10 lines of the log file is shown below.\n\n$(ssh ${node_ip} docker logs -n 10 $container_name)"
    exit 1
fi

if [ $NO_SHUTDOWN -ne 1 ]; then
    ssh ${node_ip} docker wait $container_name
fi
