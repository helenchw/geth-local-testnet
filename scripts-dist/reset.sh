#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh
set -eu

read_eth_node_list
read_signer_node_list
read_bootnode_node_list

# recreate the folder as an empty one
for (( node=1; node<=$NODE_COUNT; node++ )); do
    node_idx=$((node-1))
    node_ip=${eth_nodes[$node_idx]}
    ssh -t ${node_ip} rm -rf $ROOT/
done

ssh -t ${signer_nodes[0]} rm -rf $ROOT/
ssh -t ${bootnodes[0]} rm -rf $ROOT/

# also remove the local copy
rm -rf $ROOT/
mkdir -p $ROOT

