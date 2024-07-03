#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh
set -eu

mkdir -p $EXECUTION_DIR

new_account() {
    local node=$1
    local datadir=$2

    # Create the directory as the blockchain user for Docker containers to mount (and avoid permission conflicts)
    mkdir -p $datadir
    # Generate a new account for each geth node
    output=$(docker run --rm -u $BLOCKCHAIN_USER -v $datadir:${DATA_DIR_MOUNT_PATH} -v $ROOT/password:/password ${GETH_IMAGE}:${GETH_IMAGE_TAG} $GETH_CMD --datadir ${DATA_DIR_MOUNT_PATH} account new --password /password 2>/dev/null)
    address=$(echo $output | grep -o "0x[0-9a-fA-F]*")
    echo "Generated an account with address $address for geth node $node and saved it at $datadir"
    echo $address > $datadir/address

    # Add the account into the genesis state
    alloc=$(echo $genesis | docker run -i --rm ${JQ_CONTAINER_IMAGE}:${JQ_CONTAINER_IMAGE_TAG} ".alloc + { \"${address:2}\": { \"balance\": \"$INITIAL_BALANCE\" } }")
    genesis=$(echo $genesis | docker run -i --rm ${JQ_CONTAINER_IMAGE}:${JQ_CONTAINER_IMAGE_TAG} ". + { \"alloc\": $alloc }")
}

genesis=$(cat $GENESIS_TEMPLATE_FILE)
for (( node=1; node<=$NODE_COUNT; node++ )); do
    el_data_dir $node
    new_account "#$node" $el_data_dir
done

new_account "'signer'" $SIGNER_EL_DATADIR

# Add the extradata
zeroes() {
    for i in $(seq $1); do
        echo -n "0"
    done
}
address=$(cat $SIGNER_EL_DATADIR/address)
extra_data="0x$(zeroes 64)${address:2}$(zeroes 130)"
genesis=$(echo $genesis | docker run -i --rm ${JQ_CONTAINER_IMAGE}:${JQ_CONTAINER_IMAGE_TAG} ". + { \"extradata\": \"$extra_data\" }")

# Add the terminal total difficulty
config=$(echo $genesis | docker run -i --rm ${JQ_CONTAINER_IMAGE}:${JQ_CONTAINER_IMAGE_TAG} ".config + { \"chainId\": "$NETWORK_ID", \"terminalTotalDifficulty\": "$TERMINAL_TOTAL_DIFFICULTY", \"clique\": { \"period\": "$SECONDS_PER_ETH1_BLOCK", \"epoch\": 30000 } }")
genesis=$(echo $genesis | docker run -i --rm ${JQ_CONTAINER_IMAGE}:${JQ_CONTAINER_IMAGE_TAG} ". + { \"config\": $config }")

# Generate the genesis state
echo $genesis > $GENESIS_FILE
echo "Generated $GENESIS_FILE"

# Initialize the geth nodes' directories
for (( node=1; node<=$NODE_COUNT; node++ )); do
    el_data_dir $node
    datadir=$el_data_dir

    docker run --rm \
        -u $BLOCKCHAIN_USER \
        -v $datadir:${DATA_DIR_MOUNT_PATH} \
        -v $GENESIS_FILE:/genesis.json \
        ${GETH_IMAGE}:${GETH_IMAGE_TAG} \
        $GETH_CMD init --datadir ${DATA_DIR_MOUNT_PATH} /genesis.json \
        2>/dev/null
    echo "Initialized the data directory $datadir with $GENESIS_FILE"
done

docker run --rm \
        -u $BLOCKCHAIN_USER \
        -v $SIGNER_EL_DATADIR:${DATA_DIR_MOUNT_PATH} \
        -v $GENESIS_FILE:/genesis.json \
        ${GETH_IMAGE}:${GETH_IMAGE_TAG} \
        $GETH_CMD init --datadir ${DATA_DIR_MOUNT_PATH} /genesis.json
echo "Initialized the data directory $SIGNER_EL_DATADIR with $GENESIS_FILE"

# Generate the boot node key
docker run --rm \
    -u $BLOCKCHAIN_USER \
    -v $EXECUTION_DIR:${DATA_DIR_MOUNT_PATH} \
    ${GETH_IMAGE}:${GETH_IMAGE_TAG} \
    bootnode -genkey ${DATA_DIR_MOUNT_PATH}/boot.key
echo "Generated $EL_BOOT_KEY_FILE"
