source ./vars.env

el_data_dir() {
    el_data_dir="$ROOT/node$1/ethereum"
}

cl_data_dir() {
    cl_data_dir="$ROOT/node$1/lighthouse"
}

node_error() {
    echo -e "\n*Node Error!*: $1\n"
}

el_node_container_name() {
    container_name="$EL_NODE_CONTAIN_NAME-$1"
}

cl_bn_container_name() {
    container_name="$CL_NODE_CONTAINER_NAME-$1"
}

cl_vc_container_name() {
    container_name="$CL_VC_NODE_CONTAINER_NAME-$1"
}
