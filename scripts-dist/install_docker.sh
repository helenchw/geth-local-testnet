#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh
set -u +e

blockchain_user=$(whoami)

read_eth_node_list
read_signer_node_list
read_bootnode_node_list

curl -fsSL https://get.docker.com -o get-docker.sh
echo "docker >/dev/null 2>&1 || { bash /tmp/get-docker.sh --version 26.1.4 && usermod -aG docker ${blockchain_user} && service docker start; }" > check-docker.sh
 
remote_install_docker() {
    node_ip=$1
    echo "Installing Docker on $node_ip."
    scp get-docker.sh check-docker.sh ${node_ip}:/tmp/
    ssh -t ${node_ip} sudo bash /tmp/check-docker.sh
}

for (( node=0; node<=$((NODE_COUNT-1)); node++ )); do
    remote_install_docker ${eth_nodes[$node]}
done

remote_install_docker ${signer_nodes[0]}
remote_install_docker ${bootnodes[0]}

rm get-docker.sh check-docker.sh
