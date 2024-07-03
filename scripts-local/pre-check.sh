#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh
set -eu

# ensure this is a Linux platform
if ! test $(uname -s) = "Linux"; then
    >&2 echo "Only Linux is supported"
    exit 1
fi

# check if Docker is installed
if ! command -v docker >/dev/null; then
    echo -e "\nPlease install the latest stable version of Docker engine first.\n\n"
    exit 1
fi

# check if the folder exists. If yes, reuse the existing; otherwise, start a new one.
if test -e $ROOT; then
    >&2 echo "The folder $ROOT already exists. Reuse the existing blockchain."
    echo "0"
else
    >&2 echo "The folder $ROOT does not exist, Start a new blockchain."
    echo "1"
fi

exit 0
