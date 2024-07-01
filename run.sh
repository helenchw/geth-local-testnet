#!/usr/bin/env bash

source ./scripts/util.sh
set -u +e

start_over=1

if ! test $(uname -s) = "Linux"; then
    echo "Only Linux is supported"
fi

if ! command -v docker >/dev/null; then
    echo -e "\nPlease install the latest stable version of Docker engine first.\n\n"
    exit 1
fi

check_cmd() {
    if ! command -v $1 >/dev/null; then
        echo -e "\nCommand '$1' not found, please install it first.\n\n$2\n"
        exit 1
    fi
}

if test -e $ROOT; then
    #echo "The file $ROOT already exists, please delete or move it first."
    #exit 1
    echo "The file $ROOT already exists, reuse the existing blockchain"
    start_over=0
fi

cleanup() {
    echo "Shutting down"
    pids=$(jobs -p)
    while ps p $pids >/dev/null 2>/dev/null; do
        kill $pids 2>/dev/null
        sleep 1
    done

    #docker ps -a

    docker rm -f ${EL_BOOTNODE_CONTAINER_NAME} \
            ${CL_BOOTNODE_CONTAINER_NAME} \
            ${SIGNER_NODE_CONTAIN_NAME}

    for (( node=1; node<=$NODE_COUNT; node++ )); do
        el_node_container_name $node
        docker rm -f $container_name
    done
    for (( node=1; node<=$NODE_COUNT; node++ )); do
        cl_bn_container_name $node
        docker rm -f $container_name
    done
    for (( node=1; node<=$NODE_COUNT; node++ )); do
        cl_vc_container_name $node
        docker rm -f $container_name
    done

    #while test -e $ROOT; do
    #    rm -rf $ROOT 2>/dev/null
    #    sleep 1
    #done
    #echo "Deleted the data directory"
}

trap cleanup EXIT


if [ $start_over -eq 1 ]; then
   mkdir -p $ROOT

   # Run everything needed to generate $BUILD_DIR
   if ! ./scripts/build.sh; then
       echo -e "\n*Failed!* in the build step\n"
       exit 1
   fi
   
   if ! ./scripts/prepare-el.sh; then
       echo -e "\n*Failed!* in the execution layer preparation step\n"
       exit 1
   fi
fi

echo -e "\n> Prepare the execution layer boot node"

./scripts/el-bootnode.sh &

# Keep reading until we can parse the boot enode
echo -en "\n>> Extracting the ENR URL from the execution layer boot node log"
while true; do
    echo -en "."
    boot_enode="$(docker logs ${EL_BOOTNODE_CONTAINER_NAME} 2>/dev/null | grep -o "enode:.*$" || true)"
    if ! test -z "$boot_enode"; then
        boot_enode=$(echo ${boot_enode} | sed -e "s/127.0.0.1/${MY_NODE_IP}/")
        echo -e "\n>> ENR extracted: ${boot_enode}"
        break
    fi
    sleep 1
done

echo -e "> Prepare the execution layer worker nodes"

for (( node=1; node<=$NODE_COUNT; node++ )); do
    ./scripts/el-node.sh $node $boot_enode &
done

echo -e "> Prepare the execution layer signer node"

./scripts/signer-node.sh $SIGNER_EL_DATADIR $boot_enode &

# Wait until the signer node starts the IPC socket
while ! test -S $SIGNER_EL_DATADIR/geth.ipc; do
    sleep 1
done

if [ $start_over -eq 1 ]; then
  if ! ./scripts/prepare-cl.sh; then
      echo -e "\n*Failed!* in the consensus layer preparation step\n"
      exit 1
  fi
fi

./scripts/cl-bootnode.sh &

for (( node=1; node<=$NODE_COUNT; node++ )); do
    ./scripts/cl-bn-node.sh $node &
    ./scripts/cl-vc-node.sh $node &
done

echo -e "\nStarting on $(date)..."

wait -n
