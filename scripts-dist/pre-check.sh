#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh
set -eu

# ensure we have the IP address of all nodes

if [ ! -f ${NODE_LIST_DIR}/eth_nodes ] || [ ! -f ${NODE_LIST_DIR}/signer ] || [ ! -f ${NODE_LIST_DIR}/bootnode ]; then 
    >&2 echo -e "\nPlease ensure all node list files exist!\n"
    exit 1
fi

read_eth_node_list
read_signer_node_list
read_bootnode_node_list

if [ ${#eth_nodes[@]} -ne ${NODE_COUNT} ]; then
    >&2 echo -e "\nMismatched number of IP addresses provided for running Ethereum nodes, expecting $NODE_COUNT but got ${#eth_nodes[@]}.\n"
    exit 1
fi

if [ ${#signer_nodes[@]} -ne 1 ]; then
    >&2 echo -e "\nMismatched number of IP addresses provided for running a signer node, expecting 1 but got ${#signer_nodes[@]}.\n"
    exit 1
fi

if [ ${#bootnodes[@]} -ne 1 ]; then
    >&2 echo -e "\nMismatched number of IP addresses provided for running a bootnode, expecting 1 but got ${#bootnodes[@]}.\n"
    exit 1
fi

test_is_linux() {
    node_ip=$1
    os_version=$(ssh ${node_ip} -C uname -s)
    if [ "$os_version" != "Linux" ]; then
        >&2 echo "Only Linux is supported"
        exit 1
    fi
}

test_for_docker() {
    node_ip=$1
    if ! ssh ${node_ip} command -v docker >/dev/null; then
        >&2 echo -e "\nPlease install the latest stable version of Docker engine on ${node_ip} first.\n\n"
        exit 1
    fi
}

# ensure the machines run Linux and have Docker installed
>&2 echo "Checking platform and Docker on Ethereum nodes"
for (( node=1; node<=$NODE_COUNT; node++ )); do
    node_idx=$((node-1))
    test_is_linux ${eth_nodes[$node_idx]}
    test_for_docker ${eth_nodes[$node_idx]}
done

>&2 echo "Checking platform and Docker on signer nodes and bootnodes"
test_is_linux ${signer_nodes[0]}
test_for_docker ${signer_nodes[0]}

test_is_linux ${bootnodes[0]}
test_for_docker ${bootnodes[0]}

# check if the folder exists. If yes, reuse the existing; otherwise, start a new one.
if test -e $ROOT; then
    >&2 echo "The folder $ROOT already exists. Reuse the existing blockchain."
    echo "0"
else
    >&2 echo "The folder $ROOT does not exist, Start a new blockchain."
    echo "1"
fi

exit 0
