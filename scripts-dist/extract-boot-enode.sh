#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh
set -eu

read_bootnode_node_list
node_ip=${bootnodes[0]}

# Keep reading until we can parse the boot enode
>&2 echo -e "Extracting the ENR URL from the execution layer boot node log...\n"
while true; do
    boot_enode="$(ssh ${node_ip} docker logs ${EL_BOOTNODE_CONTAINER_NAME} 2>/dev/null | grep -o "enode:.*$" || true)"
    if ! test -z "$boot_enode"; then
        boot_enode=$(echo ${boot_enode} | sed -e "s/127.0.0.1/${node_ip}/")
        echo ${boot_enode}
        exit 0
    fi
    sleep 1
done

exit 1
