#!/usr/bin/env bash

set -u +e

start_over=1
local_mode=1
scripts_dir="./scripts-local"

source vars.env

# determine the blockchain architecture type: local or distributed
if [ ${DEPLOYMENT_MODE} -eq 0 ]; then  # local
    echo "> Running a local blockchain. $(date) <"
elif [ ${DEPLOYMENT_MODE} -eq 1 ]; then  # distributed
    # swtich the scripts to use
    local_mode=0
    scripts_dir="./scripts-dist"
    echo "> Running a distributed blockchain. $(date) <"
fi

cleanup() {
    echo "Shutting down"
    pids=$(jobs -p)
    while ps p $pids >/dev/null 2>/dev/null; do
        kill $pids 2>/dev/null
        sleep 1
    done

    ${scripts_dir}/shutdown.sh
}

trap cleanup EXIT

# include utility functions
source ${scripts_dir}/util.sh

# run other pre-checks
start_over=$(${scripts_dir}/pre-check.sh)
if [ $FORCE_START_OVER -eq 0 ]; then
    start_over=$((start_over))
else
    start_over=1
fi

# print the node information for a distributed setup
if [ $local_mode -ne 1 ]; then
    read_eth_node_list
    read_signer_node_list
    read_bootnode_node_list
    echo -e "-------------- Deployment Summary ----------------"
    echo -e "Singer node: ${signer_nodes[0]}"
    echo -e "Bootnodes: ${bootnodes[0]}"
    echo -e "A tuple of execution client, consensus client, and validator client on ${NODE_COUNT} nodes:"
    for (( node=1; node <= $NODE_COUNT; node++ )); do
        node_idx=$((node-1))
        echo -e " ${node}: ${eth_nodes[$node_idx]}"
    done
    echo -e "--------------------------------------------------"
fi

if [ $start_over -eq 1 ]; then
    read -p "Going to reset everything! Continue (Y/N)?  " res
    if [ "${res}" != "Y" ] && [ "${res}" != "y" ]; then
        echo "Abort reset."
        exit 0
    fi

    # reset the root data directory on all nodes
    ${scripts_dir}/reset.sh
 
    # Run everything needed to generate $BUILD_DIR
    if ! ${scripts_dir}/build.sh; then
        echo -e "\n*Failed!* in the build step\n"
        exit 1
    fi
    
    # Prepare the execution layer
    if ! ${scripts_dir}/prepare-el.sh; then
        echo -e "\n*Failed!* in the execution layer preparation step\n"
        exit 1
    fi
fi

echo -e "Run the execution layer boot node"

${scripts_dir}/el-bootnode.sh &

boot_enode=$(${scripts_dir}/extract-boot-enode.sh)
if test -z "${boot_enode}"; then
    echo -e "\n*Failed!* Cannot extract the execution boot node ENR\n"
    exit 1
fi
echo -e "Execution boot node ENR extracted: ${boot_enode}"

echo -e "Run the execution layer nodes"

${scripts_dir}/el-nodes.sh $boot_enode &

echo -e "Run the execution layer signer node"

${scripts_dir}/signer-node.sh $boot_enode &

${scripts_dir}/wait-signer-node.sh

# Prepare the consensus layer
if [ $start_over -eq 1 ]; then
  if ! ${scripts_dir}/prepare-cl.sh; then
      echo -e "\n*Failed!* in the consensus layer preparation step\n"
      exit 1
  fi
else
  # wait for the el nodes to be ready
  sleep 5
fi


echo -e "Run the consensus layer boot node"

${scripts_dir}/cl-bootnode.sh &

echo -e "Run the consensus layer nodes"

${scripts_dir}/cl-nodes.sh &

echo -e "\nFinished starting all nodes!"

if [ $NO_SHUTDOWN -ne 0 ]; then
    trap - EXIT
fi

wait -n
