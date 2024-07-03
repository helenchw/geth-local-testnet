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

for (( node=1; node<=$NODE_COUNT; node++ )); do
    ${pdir}/cl-bn-node.sh $node &
    ${pdir}/cl-vc-node.sh $node &
done

wait -n
