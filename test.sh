#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/config.sh

basedir=$(dirname $0)

function usage {
  local msg=$1
  echo
  echo $msg
  echo
  echo "Usage: $0 <nodes, space separted>"
  exit 1
}

nodes=$1
if [ -z "$nodes" ]; then
  nodes="ctrl"
fi

set -e

ping -c 1 172.24.4.1 >/dev/null || usage "No route to floating ip pool: 172.24.4.0/24"

ssh-keygen -f "/home/cluk/.ssh/known_hosts" -R 10.33.0.1
ssh-keygen -f "/home/cluk/.ssh/known_hosts" -R 10.33.0.10
ssh-keygen -f "/home/cluk/.ssh/known_hosts" -R 10.33.0.11
for node in $nodes; do
  ssh-keygen -f "/home/cluk/.ssh/known_hosts" -R $node
  ssh-copy-id ubuntu@$node
done

ssh-add  $COOKBOOK_BASE/keystore/pingworks/.ssh/id_rsa

setup_basics
setup_docker_imgs "" "$nodes"
setup_glance_imgs ""

setup_users pingworks
$SCRIPTDIR/env-create.sh pingworks envs/single-vm-from-baseimg-for-test sub1
$SCRIPTDIR/env-create.sh pingworks envs/single-vm-from-baseimg-for-test sub2
