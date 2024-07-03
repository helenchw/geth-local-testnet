#!/usr/bin/env bash

set -eu

pdir=$(dirname "${BASH_SOURCE[0]}")

source ${pdir}/util.sh
boot_enode=$1

cleanup() {
    pids=$(jobs -p)
    while ps p $pids >/dev/null 2>/dev/null; do
        kill $pids 2>/dev/null
        sleep 1
    done
}

trap cleanup EXIT

read_eth_node_list

for (( node=1; node<=$NODE_COUNT; node++ )); do
    node_idx=$((node-1))
    node_ip=${eth_nodes[$node_idx]}
    el_data_dir $node
    address=$(cat ${el_data_dir}/address)
    ${pdir}/el-node.sh $node_ip $boot_enode $address &
done

wait -n
