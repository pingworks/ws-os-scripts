#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/common.sh

OS_USER="ubuntu"
OS_CTRL="10.33.0.10"
EXEC="ssh ${OS_USER}@${OS_CTRL}"
DOMAIN="ws.pingworks.net"

if [ ! -z "$1" ]; then
  DOMAIN="$1.$DOMAIN"
fi

set -e

for host in $(get_instances_in_domain $DOMAIN); do
  echo "====> Deleting instance: $host .."
  delete instance $host
  echo "====> done."
  echo
done

echo "====> Deleting dns zone: $DOMAIN .."
DNS_ZONE_ID=$(get_and_delete domain $DOMAIN)
echo "====> done."
echo
