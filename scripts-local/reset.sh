#!/usr/bin/env bash

source $(dirname "${BASH_SOURCE[0]}")/util.sh
set -eu

# recreate the folder as an empty one
rm -rf $ROOT/
mkdir -p $ROOT

