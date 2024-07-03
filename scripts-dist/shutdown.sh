#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh

read_eth_node_list
read_signer_node_list
read_bootnode_node_list

# terminate the nodes gracefully to avoid data loss
echo -e "Stopping the Docker containers of nodes..."
for (( node=1; node<=$NODE_COUNT; node++ )); do
    node_idx=$((node-1)) 
    container_names=()
    cl_vc_container_name $node
    container_names+=($container_name)
    cl_bn_container_name $node
    container_names+=($container_name)
    el_node_container_name $node
    container_names+=($container_name)

    ssh ${eth_nodes[$node_idx]} docker stop ${container_names[@]}
done

ssh ${signer_nodes[0]} docker stop ${SIGNER_NODE_CONTAIN_NAME}
ssh ${bootnodes[0]} docker stop ${EL_BOOTNODE_CONTAINER_NAME} ${CL_BOOTNODE_CONTAINER_NAME}

echo -e "Removing the Docker containers of nodes..."
# clean up the node containers
for (( node=1; node<=$NODE_COUNT; node++ )); do
    node_idx=$((node-1)) 
    container_names=()
    cl_vc_container_name $node
    container_names+=($container_name)
    cl_bn_container_name $node
    container_names+=($container_name)
    el_node_container_name $node
    container_names+=($container_name)

    ssh ${eth_nodes[$node_idx]} docker rm ${container_names[@]}
done

ssh ${signer_nodes[0]} docker rm ${SIGNER_NODE_CONTAIN_NAME}
ssh ${bootnodes[0]} docker rm ${EL_BOOTNODE_CONTAINER_NAME} ${CL_BOOTNODE_CONTAINER_NAME}

echo -e "Completed shutdown."
