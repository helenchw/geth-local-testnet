#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh
set -eu

# Keep reading until we can parse the boot enode
>&2 echo -e "Extracting the ENR URL from the execution layer boot node log...\n"
while true; do
    boot_enode="$(docker logs ${EL_BOOTNODE_CONTAINER_NAME} 2>/dev/null | grep -o "enode:.*$" || true)"
    if ! test -z "$boot_enode"; then
        boot_enode=$(echo ${boot_enode} | sed -e "s/127.0.0.1/${MY_NODE_IP}/")
        echo ${boot_enode}
        break
    fi
    sleep 1
done
