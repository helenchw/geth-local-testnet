#!/usr/bin/env bash

set -u +e

pdir=$(dirname "${BASH_SOURCE[0]}")

source ${pdir}/util.sh

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
    ${pdir}/cl-bn-node.sh $node_ip &
    ${pdir}/cl-vc-node.sh $node_ip &
done

wait -n
