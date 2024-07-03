#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh
set -u +e

cleanup() {
    kill $(jobs -p) 2>/dev/null
}

trap cleanup EXIT

index=$1

cl_data_dir $index
cl_bn_container_name $index
datadir=$cl_data_dir
udp_port=$(expr $BASE_CL_PORT + $index + $index)
tcp_port=$(expr $BASE_CL_PORT + $index + $index + 1)
http_port=$(expr $BASE_CL_HTTP_PORT + $index)
log_file=${DATA_DIR_MOUNT_PATH}/beacon_node.log

echo "Started the lighthouse beacon node #$index which is now listening at ports $udp_port and $tcp_port, and http at port $http_port. You can see the log at $log_file"

# --disable-packet-filter is necessary because it's involed in rate limiting and nodes per IP limit
# See https://github.com/sigp/discv5/blob/v0.1.0/src/socket/filter/mod.rs#L149-L186
# TODO: We are directly exposing the host network to the container with '--network host'. Is it possible to run without this option?
docker run -d \
    -u ${BLOCKCHAIN_USER} \
    -v $datadir:${DATA_DIR_MOUNT_PATH} \
    -v $CONSENSUS_DIR:${CONSENSUS_DIR_MOUNT_PATH} \
    -p $udp_port:$udp_port/udp \
    -p $udp_port:$udp_port \
    -p $tcp_port:$tcp_port/udp \
    -p $tcp_port:$tcp_port \
    -p $http_port:$http_port \
    ${COMMON_NODE_CONTAINER_OPTIONS} \
    --name ${container_name} \
    --network host \
    ${LIGHTHOUSE_IMAGE}:${LIGHTHOUSE_IMAGE_TAG} \
    $LIGHTHOUSE_CMD beacon_node \
    --datadir ${DATA_DIR_MOUNT_PATH} \
	--testnet-dir ${CONSENSUS_DIR_MOUNT_PATH} \
    --execution-endpoint http://${MY_NODE_IP}:$(expr $BASE_EL_RPC_PORT + $index) \
    --execution-jwt ${DATA_DIR_MOUNT_PATH}/jwtsecret \
	--enable-private-discovery \
	--staking \
    --enr-address ${MY_NODE_IP} \
	--enr-udp-port $udp_port \
	--enr-tcp-port $tcp_port \
	--port $udp_port \
    --http \
	--http-port $http_port \
    --http-address 0.0.0.0 \
	--disable-packet-filter \
    --logfile $log_file \
    --logfile-debug-level "info"

if test $? -ne 0; then
    node_error "The lighthouse beacon node #$index returns an error. The last 10 lines of the log file is shown below.\n\n$(docker logs -n 10 $container_name)"
    exit 1
fi

docker wait $container_name
