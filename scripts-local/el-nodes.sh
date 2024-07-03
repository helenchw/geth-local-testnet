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

for (( node=1; node<=$NODE_COUNT; node++ )); do
    ${pdir}/el-node.sh $node $boot_enode &
done

wait -n
