source ./vars.env

el_data_dir() {
    el_data_dir="$ROOT/node$1/ethereum"
}

cl_data_dir() {
    cl_data_dir="$ROOT/node$1/lighthouse"
}

el_remote_data_dir() {
    el_remote_data_dir="$ROOT/node/ethereum"
}

cl_remote_data_dir() {
    cl_remote_data_dir="$ROOT/node/lighthouse"
}

node_error() {
    echo -e "\n*Node Error!*: $1\n"
}

el_node_container_name() {
    container_name="$EL_NODE_CONTAIN_NAME"
}

cl_bn_container_name() {
    container_name="$CL_NODE_CONTAINER_NAME"
}

cl_vc_container_name() {
    container_name="$CL_VC_NODE_CONTAINER_NAME"
}

read_eth_node_list() {
    readarray -t eth_nodes < ${NODE_LIST_DIR}/eth_nodes 
}

read_signer_node_list() {
    readarray -t signer_nodes < ${NODE_LIST_DIR}/signer
}

read_bootnode_node_list() {
    readarray -t bootnodes < ${NODE_LIST_DIR}/bootnode
}
