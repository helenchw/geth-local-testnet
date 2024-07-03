#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh

# terminate the nodes gracefully to avoid data loss
echo -e "Stopping the Docker containers of nodes..."
for (( node=1; node<=$NODE_COUNT; node++ )); do
    cl_vc_container_name $node
    docker stop $container_name
done
for (( node=1; node<=$NODE_COUNT; node++ )); do
    cl_bn_container_name $node
    docker stop $container_name
done
for (( node=1; node<=$NODE_COUNT; node++ )); do
    el_node_container_name $node
    docker stop $container_name
done

docker stop ${EL_BOOTNODE_CONTAINER_NAME} \
        ${CL_BOOTNODE_CONTAINER_NAME} \
        ${SIGNER_NODE_CONTAIN_NAME}

echo -e "Removing the Docker containers of nodes..."
# clean up the node containers
for (( node=1; node<=$NODE_COUNT; node++ )); do
    cl_vc_container_name $node
    docker rm $container_name
done
for (( node=1; node<=$NODE_COUNT; node++ )); do
    cl_bn_container_name $node
    docker rm $container_name
done
for (( node=1; node<=$NODE_COUNT; node++ )); do
    el_node_container_name $node
    docker rm $container_name
done

docker rm ${EL_BOOTNODE_CONTAINER_NAME} \
        ${CL_BOOTNODE_CONTAINER_NAME} \
        ${SIGNER_NODE_CONTAIN_NAME}

echo -e "Completed shutdown."
