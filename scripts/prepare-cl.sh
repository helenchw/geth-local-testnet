#!/usr/bin/env bash

source ./scripts/util.sh
set -eu

mkdir -p $CONSENSUS_DIR

if ! test -e ./web3/node_modules; then
    echo "The package ./web3 doesn't have node modules installed yet. Installing the node modules now"
    mkdir ./web3/.npm
    docker run --rm -u ${BLOCKCHAIN_USER} -v ./web3:${WEB3_DIR_MOUNT_PATH} -v ./web3/.npm:/.npm ${NODE_CONTAINER_IMAGE}:${NODE_CONTAINER_IMAGE_TAG} npm --proxy="$HTTP_PROXY" --prefix ${WEB3_DIR_MOUNT_PATH} install >/dev/null 2>/dev/null
    echo "Node modules are already installed"
fi

# wait for the signer node to be ready
sleep 2

# Use the signing node as a node to deploy the deposit contract
output=$(docker run --rm -u ${BLOCKCHAIN_USER} -v ./web3:${WEB3_DIR_MOUNT_PATH} -v $SIGNER_EL_DATADIR:${DATA_DIR_MOUNT_PATH} -v ./assets:/assets -w / -e NODE_PATH=${WEB3_DIR_MOUNT_PATH}/node_modules ${NODE_CONTAINER_IMAGE}:${NODE_CONTAINER_IMAGE_TAG} node ${WEB3_DIR_MOUNT_PATH}/src/deploy-deposit-contract.js --endpoint ${DATA_DIR_MOUNT_PATH}/geth.ipc)
address=$(echo "$output" | grep "address" | cut -d ' ' -f 2)
transaction=$(echo "$output" | grep "transaction" | cut -d ' ' -f 2)
block_number=$(echo "$output" | grep "block_number" | cut -d ' ' -f 2)

echo "Deployed the deposit contract of the address $address in the transaction $transaction on the block number $block_number"

# wait for the deployment transaction to complete
sleep 2

echo $address > $ROOT/deposit-address
echo $block_number > $CONSENSUS_DIR/deploy_block.txt

# Select the validator
mkdir -p $CONSENSUS_DIR/validator_keys
docker run --rm \
    -u ${BLOCKCHAIN_USER} \
    -v ./web3:${WEB3_DIR_MOUNT_PATH} \
    -v $CONSENSUS_DIR:$CONSENSUS_DIR_MOUNT_PATH \
    -v $BUILD_DIR:${BUILD_DIR_MOUNT_PATH} \
    -e NODE_PATH=${WEB3_DIR_MOUNT_PATH}/node_modules \
    ${NODE_CONTAINER_IMAGE}:${NODE_CONTAINER_IMAGE_TAG} \
    node ${WEB3_DIR_MOUNT_PATH}/src/distribute-validators.js \
    --nc $NODE_COUNT \
    --vc $VALIDATOR_COUNT \
    -d ${BUILD_DIR_MOUNT_PATH}/validator_keys \
    -o ${CONSENSUS_DIR_MOUNT_PATH}/validator_keys \
    > $ROOT/deposit-data.json

echo "Sending the deposits to the deposit contract"
docker run --rm \
    -u ${BLOCKCHAIN_USER} \
    -v ./web3:${WEB3_DIR_MOUNT_PATH} \
    -v $SIGNER_EL_DATADIR:${DATA_DIR_MOUNT_PATH} \
    -v $ROOT/deposit-data.json:/deposit-data.json \
    -v ./assets:/assets \
    -w / \
    -e NODE_PATH=${WEB3_DIR_MOUNT_PATH}/node_modules \
    ${NODE_CONTAINER_IMAGE}:${NODE_CONTAINER_IMAGE_TAG} \
    node ${WEB3_DIR_MOUNT_PATH}/src/transfer-deposit.js \
    --endpoint ${DATA_DIR_MOUNT_PATH}/geth.ipc \
    --deposit-address $address \
    -f /deposit-data.json
echo -e "\nDone sending all the deposits to the contract"

cp $CONFIG_TEMPLATE_FILE $CONFIG_FILE
echo "PRESET_BASE: \"$PRESET_BASE\"" >> $CONFIG_FILE
echo "TERMINAL_TOTAL_DIFFICULTY: \"$TERMINAL_TOTAL_DIFFICULTY\"" >> $CONFIG_FILE
echo "MIN_GENESIS_ACTIVE_VALIDATOR_COUNT: \"$VALIDATOR_COUNT\"" >> $CONFIG_FILE
echo "MIN_GENESIS_TIME: \"$(expr $(date +%s) + $GENESIS_DELAY)\"" >> $CONFIG_FILE
echo "GENESIS_DELAY: \"$GENESIS_DELAY\"" >> $CONFIG_FILE
echo "GENESIS_FORK_VERSION: \"$GENESIS_FORK_VERSION\"" >> $CONFIG_FILE

echo "DEPOSIT_CHAIN_ID: \"$NETWORK_ID\"" >> $CONFIG_FILE
echo "DEPOSIT_NETWORK_ID: \"$NETWORK_ID\"" >> $CONFIG_FILE
echo "DEPOSIT_CONTRACT_ADDRESS: \"$address\"" >> $CONFIG_FILE

echo "SECONDS_PER_SLOT: \"$SECONDS_PER_SLOT\"" >> $CONFIG_FILE
echo "SECONDS_PER_ETH1_BLOCK: \"$SECONDS_PER_ETH1_BLOCK\"" >> $CONFIG_FILE

echo "Generated $CONFIG_FILE"

docker run --rm \
    -u $BLOCKCHAIN_USER \
    -v $CONSENSUS_DIR:${CONSENSUS_DIR_MOUNT_PATH} \
    ${LIGHTHOUSE_CLI_IMAGE}:${LIGHTHOUSE_CLI_IMAGE_TAG} \
    lcli eth1-genesis \
    --spec $PRESET_BASE \
    --eth1-endpoints http://${MY_NODE_IP}:$SIGNER_HTTP_PORT \
    --testnet-dir ${CONSENSUS_DIR_MOUNT_PATH} \
    2>/dev/null

echo "Generated $CONSENSUS_DIR/genesis.ssz"

docker run --rm \
    -u $BLOCKCHAIN_USER \
    -v $CONSENSUS_DIR:${CONSENSUS_DIR_MOUNT_PATH} \
    ${LIGHTHOUSE_CLI_IMAGE}:${LIGHTHOUSE_CLI_IMAGE_TAG} \
    lcli \
	generate-bootnode-enr \
	--ip ${MY_NODE_IP} \
	--udp-port $CL_BOOTNODE_PORT \
	--tcp-port $CL_BOOTNODE_PORT \
	--genesis-fork-version $GENESIS_FORK_VERSION \
	--output-dir ${CONSENSUS_DIR_MOUNT_PATH}/bootnode

bootnode_enr=$(cat $CL_BOOTNODE_DIR/enr.dat)
echo "- $bootnode_enr" > $CONSENSUS_DIR/boot_enr.yaml
echo "Generated $CONSENSUS_DIR/boot_enr.yaml"

echo "Importing the keystores of the validators to the lighthouse data directories"
for (( node=1; node<=$NODE_COUNT; node++ )); do
    cl_data_dir $node
    el_data_dir $node
    mkdir -p $cl_data_dir
    cp $el_data_dir/geth/jwtsecret $cl_data_dir
    docker run --rm \
        -u ${BLOCKCHAIN_USER} \
        -v $ROOT/password:/password \
        -v $CONSENSUS_DIR:${CONSENSUS_DIR_MOUNT_PATH} \
        -v $cl_data_dir:${DATA_DIR_MOUNT_PATH} \
        ${LIGHTHOUSE_IMAGE}:${LIGHTHOUSE_IMAGE_TAG} \
        $LIGHTHOUSE_CMD \
        account validator import \
        --testnet-dir ${CONSENSUS_DIR_MOUNT_PATH} \
        --directory ${CONSENSUS_DIR_MOUNT_PATH}/validator_keys/node$node \
        --datadir ${DATA_DIR_MOUNT_PATH} \
        --password-file /password \
        --reuse-password \
        2>/dev/null
    echo -n "."
done
echo -e "\nDone importing the keystores"
