# Local Ethereum Testnet
Run a full Ethereum network from genesis on a local machine or a cluster of local machines (i.e., a distributed blockchain deployment).
The network run by this projects uses [lighthouse](https://github.com/sigp/lighthouse) and [geth](https://github.com/ethereum/go-ethereum) as the consensus client and execution client respectively.

We try to make the network as similar to the mainnet as possible, so that people can use this repository as the documentation on how to start
their own network.

In order to do so, we try to write as little code as possible and use only bash scripts to run only well-known softwares. In addition, we use some
JavaScript and web3.js so that we can easily manage JSON objects and interact with the Ethereum nodes.

## Test Machine Environment

- Operating System: Ubuntu 22.04.2 LTS (64-bit) Server
- Docker: v26.1.4
  
The scripts use packaged Docker images with the following software:

- Geth: v1.13.15
- Lighthouse: v5.1.3
- Node: v22.0
- JQ: latest

Their versions are configurable in the file `vars.env`.

## Distributed Deployment 

For a distributed deployment, we assume the following architecture with one bootstrap node, one node for a signer and bootnodes, and multiple nodes for a tuple of execution client, consensus client, and validator client.
All nodes are in the same (LAN) network segment where the blockchain runs.
All nodes should be accessible from the bootstrap node over SSH without any password (see an example of password-less SSH setup [here][passwordless-ssh]).
The user running the script `run.sh` should be the blockchain user which has the same Linux user ID across the nodes.

```
                Operations
+-----------+    over SSH    +-----------------------------------------+
| Bootstrap | -------------> | Execution bootnode & concensus bootnode |
+-----------+       |        +-----------------------------------------+
                    |
                    |        +--------+
                    |------> | Signer |
                    |        +--------+
                    |
                    |        +--------------------------------------------------------+
                    |------> | Execution client & concensus client & validator client |
                    |        +--------------------------------------------------------+
                    |             ...
                    |        +--------------------------------------------------------+
                    \------> | Execution client & concensus client & validator client |
                             +--------------------------------------------------------+
```

[passwordless-ssh]: https://www.redhat.com/sysadmin/passwordless-ssh


## Update Deployment Configurations

Update the configurations in `vars.env`

1. Blockchain deployment mode, `DEPLOYMENT_MODE`: 0 for local and 1 for distributed
1. Blockchain-running Linux user ID: set it to the value obtained by running `id -u`
1. For local deployment, update `MY_NODE_IP`to the host machine LAN IP address.
1. If the machines are behind an HTTP proxy for Internet access, set `HTTP_PROXY` to the proxy address.


For a distributed deployment, you need to update the lists of cluster nodes in the respective files.

- `nodes_list/bootnode`: IP address for the bootnodes
- `nodes_list/signer`: IP address for the signer 
- `nodes_list/eth_nodes`: IP address of the nodes running a tuple of execution client, consensus client, and validator client


## Install Dependencies
You can follow the instructions below to install the dependencies on **every machine**. You can omit some instructions if you prefer to install them in other ways.

```bash
# Install Docker 26.1.4
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh --version 26.1.4
sudo service docker start
```

Alternatively for distributed deployment, you can run `scripts-dist/install_docker.sh` install Docker on all machines that are configured in the designated lists under the `node_lists` folder.
The script requires `sudo` access of the machines.
If the blockchain-running user differs from the one for installation (e.g., admin), update the `user` variable in the script to the blockchain user name and run as the installation user.
If the machines are behind a HTTP proxy for Internet access, update the Docker daemon configurations accordingly, e.g.,

1. Set 'HTTP_PROXY' and 'HTTPS_PROXY' environment variables in the Docker systemd service file, e.g., `/lib/systemd/system/docker.service`
```bash
[Service]
...
Environment="HTTP_PROXY=<proxy_server_address>"
Environment="HTTPS_PROXY=<proxy_server_address>"
```
1. Reload the systemd daemon and restart the Docker systemd service
```bash
sudo systemctl daemon-reload
sudo systemctl restart docker
```

## Update user permission
Add the blockchain-running user to the Docker group for using Docker on **every machine**.

```bash
sudo usermod -aG docker <blockchain_user_name>
```

## Run the network
```bash
git clone https://github.com/ppopth/local-testnet.git
cd local-testnet
./run.sh
```
By default, the number of nodes will be 4 and the number of validators will be 4. You can change them by setting the environment variables.
```bash
NODE_COUNT=2 VALIDATOR_COUNT=10 ./run.sh
```
Note: If you make the `NODE_COUNT` and `VALIDATOR_COUNT` too high, you probably need to change `TERMINAL_TOTAL_DIFFICULTY` and `GENESIS_DELAY` in `vars.env` as well. Please read the comment in `vars.env` for more detail.

### Maintenance

To manually shutdown the blockchain,

- For local deployment, run `./scripts-local/shutdown.sh`
- For distributed deployment, run `./scripts-dist/shutdown.sh`

To manually clean the blockchain directories,

- For local deployment, run `./scripts-local/reset.sh`
- For distributed deployment, run `./scripts-dist/reset.sh`

Note that the scripts **does not support automated switch between deployment modes**.
If you want to switch between modes, either use different blockchain directories for different modes or manually clean the blockchain directories.

## How the network works
When you run `./run.sh`, the followings happen in order.

1. Ethereum accounts are generated for each node using the command `geth account new`, so there will be `NODE_COUNT` accounts in total.
2. Execution layer genesis file is generated at `./data/execution/genesis.json`.
3. Geth directories of each node are initialized with the previously generated gnesis file.
4. Start a boot node of the execution layer p2p network.
5. Start Geth instances of all `NODE_COUNT` nodes.
6. Start a Geth instance of a special node called "signer".

At this point, there will be `NODE_COUNT` Geth nodes, a boot node, and the "signer" Geth node running. They form a network and they can discover
each other using the boot node. The network is now a fully functioning Ethereum network, but its underlying consensus protocol is a Proof-of-Authority (PoA) protocol,
not the desired Proof-of-Stake (PoS) protocol. (You can try sending a transactoin at this stage, if you want)

In case you're curious, "signer" is a dedicated node used as the only block-proposing authority of the Proof-of-Stake protocol.

The next steps are about turning the network into the Proof-of-Stake one.

7. Deploy the deposit contract using one of the PoA nodes.
8. Generate the key pairs of all `VALIDATOR_COUNT` validators using [staking-deposit-cli](https://github.com/ethereum/staking-deposit-cli).
9. Sending the deposits to the deposit contract for all the validators using one of the PoA nodes.
10. Consensus layer genesis file is generated at `./data/consensus/genesis.ssz`.
11. Assign the validators to the `NODE_COUNT` nodes. Every node will have approximately the same number of validators.
12. Start a boot node of the consensus layer p2p network.
13. Start Lighthouse instances of all `NODE_COUNT` nodes.

At this point, everything is ready to transition to the Proof-of-Stake.

Using the default configuration, you will have to wait around **5 minutes** since you start the network until it fully transitions to the Proof-of-Stake.

## Inspect the logs

The following logs are the significant ones.
* *./data/signer/ethereum/geth.log* - which is the Geth log of the "signer" node.
* *./data/node{id}/ethereum/geth.log* - which is the Geth log of the id'th node of the `NODE_COUNT` nodes.
* *./data/node{id}/lighthouse/beacon_node.log* - which is the Lighthouse beacon_node log of the id'th node of the `NODE_COUNT` nodes.
* *./data/node{id}/lighthouse/validator_client.log* - which is the Lighthouse validator_client log of the id'th node of the `NODE_COUNT` nodes.

When the network has fully transitioned to the Proof-of-Stake, the log in *./data/node{id}/lighthouse/beacon_node.log* should show the following.

```
Jan 06 10:09:53.501 INFO Synced                                  slot: 71, block: 0xfa3e…e9bb, epoch: 2, finalized_epoch: 0, finalized_root: 0x68ea…8fbd, exec_hash: n/a, peers: 3, service: slot_notifier
Jan 06 10:09:53.504 INFO Ready for the merge                     current_difficulty: 159, terminal_total_difficulty: 160, service: slot_notifier
Jan 06 10:09:55.037 INFO New block received                      root: 0x60c2d96ce0d90e08686900df41966e34afd467e5d93527046435f284fe139333, slot: 72
Jan 06 10:09:55.044 INFO 
    ,,,         ,,,                                               ,,,         ,,,
  ;"   ^;     ;'   ",                                           ;"   ^;     ;'   ",
  ;    s$$$$$$$s     ;                                          ;    s$$$$$$$s     ;
  ,  ss$$$$$$$$$$s  ,'  ooooooooo.    .oooooo.   .oooooo..o     ,  ss$$$$$$$$$$s  ,'
  ;s$$$$$$$$$$$$$$$     `888   `Y88. d8P'  `Y8b d8P'    `Y8     ;s$$$$$$$$$$$$$$$
  $$$$$$$$$$$$$$$$$$     888   .d88'888      888Y88bo.          $$$$$$$$$$$$$$$$$$
 $$$$P""Y$$$Y""W$$$$$    888ooo88P' 888      888 `"Y8888o.     $$$$P""Y$$$Y""W$$$$$
 $$$$  p"LFG"q  $$$$$    888        888      888     `"Y88b    $$$$  p"LFG"q  $$$$$
 $$$$  .$$$$$.  $$$$     888        `88b    d88'oo     .d8P    $$$$  .$$$$$.  $$$$
  $$DcaU$$$$$$$$$$      o888o        `Y8bood8P' 8""88888P'      $$DcaU$$$$$$$$$$
    "Y$$$"*"$$$Y"                                                 "Y$$$"*"$$$Y"
        "$b.$$"                                                       "$b.$$"

       .o.                   .   o8o                         .                 .o8
      .888.                .o8   `"'                       .o8                "888
     .8"888.     .ooooo. .o888oooooo oooo    ooo .oooo.  .o888oo .ooooo.  .oooo888
    .8' `888.   d88' `"Y8  888  `888  `88.  .8' `P  )88b   888  d88' `88bd88' `888
   .88ooo8888.  888        888   888   `88..8'   .oP"888   888  888ooo888888   888
  .8'     `888. 888   .o8  888 . 888    `888'   d8(  888   888 .888    .o888   888
 o88o     o8888o`Y8bod8P'  "888"o888o    `8'    `Y888""8o  "888"`Y8bod8P'`Y8bod88P"

, service: beacon
Jan 06 10:09:55.044 INFO Proof of Stake Activated                slot: 72, service: beacon
Jan 06 10:09:55.044 INFO                                         Terminal POW Block Hash: 0xc2bc20ed0a3903d9e93dbd31abbc867a0a7c38240cb6a194575fdd5bcb466e12, service: beacon
Jan 06 10:09:55.044 INFO                                         Merge Transition Block Root: 0x60c2d96ce0d90e08686900df41966e34afd467e5d93527046435f284fe139333, service: beacon
Jan 06 10:09:55.044 INFO                                         Merge Transition Execution Hash: 0xede8bfd80096085da44b8954aa071ca3d82eced8c4c2bd57941b0a4b616bc456, service: beacon
Jan 06 10:09:56.502 INFO Synced                                  slot: 72, block: 0x60c2…9333, epoch: 2, finalized_epoch: 0, finalized_root: 0x68ea…8fbd, exec_hash: 0xede8…c456 (verified), peers: 3, service: slot_notifier
```

## Try sending a transaction

Save the following file as `send.js`
```js
const net = require('net');
const Web3 = require('web3');
const web3 = new Web3('./data/node1/ethereum/geth.ipc', net);

const recipient = process.argv[2];

(async function() {
    const accounts = await web3.eth.getAccounts();

    console.log("Before the transaction:");
    console.log(accounts[0], "has", await web3.eth.getBalance(accounts[0]));
    console.log(recipient, "has", await web3.eth.getBalance(recipient));

    await web3.eth.sendTransaction({
        from: accounts[0],
        to: recipient,
        value: '500000000000000000000000000',
        gas: 42000,
        gasPrice: '14000000000',
    });

    console.log("After the transaction:");
    console.log(accounts[0], "has", await web3.eth.getBalance(accounts[0]));
    console.log(recipient, "has", await web3.eth.getBalance(recipient));
})();
```
Run the following to send a transaction. This can take a while, so be patient.
```
$ NODE_PATH=./web3/node_modules node send.js $(cat ./data/node2/ethereum/address)
Before the transaction:
0x7CC1c30f38606C767d6F930Ef82E51571Da15015 has 1000000000000000000000000000
0x1f7702a321566a68Cd6edD20b55f7Fe8641c8344 has 1000000000000000000000000000
After the transaction:
0x7CC1c30f38606C767d6F930Ef82E51571Da15015 has 499999999999706000000000000
0x1f7702a321566a68Cd6edD20b55f7Fe8641c8344 has 1500000000000000000000000000
```

## Changes w.r.t. the upstream

- Support both local and distributed deployment

### Operational
- Only initialize the network when the blockchain directory does not exist
- Switch to use Docker images for all dependent software (Geth, Lighthouse, jq, node, npm)
- Add different operation configurations in `vars.env`
  - `DEPLOYMENT_MODE`
     - `0`: local
     - `1`: for distributed
  - `FORCE_START_OVER`
     - `0`: if all blockchain directories exist, reuse them. Useful for restarting an existing blockchain.
     - `1`: always reset the blockchain directories and start a new blockchain. Useful for testing.
  - `NO_SHUTDOWN`
     - `0`: wait until a TERM signal and shutdown the blockchain
     - `1`: exit the script once everything is up without any wait or shutdown

### Configurations
- Use a separate port number for TCP for Lighthouse consensus nodes
- Expose the HTTP API endpoint for Geth execution nodes (7600 + index)
- Specify `--miner.etherbase` for the Geth signer node
- Use `--logfile` flags for Geth and Lighthouse for continued logging across restarts
- Reduce the default validator count to 4

### Runtime
- Add some waiting time for deposit contract deployment to complete
