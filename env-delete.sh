#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/config.sh
. $SCRIPTDIR/common.sh

OS_SSH_USER="ubuntu"
OS_CTRL="10.33.0.10"
EXEC="ssh ${OS_SSH_USER}@${OS_CTRL}"
BASEDOMAIN="ws.pingworks.net"

function usage {
  local msg=$1
  echo
  echo $msg
  echo
  echo "Usage: $0 <user> <subdomain>"
  exit 1
}

USER=$1
if [ -z "$USER" ]; then
  usage
fi
OS_USER=$USER

DOMAIN="$USER.$BASEDOMAIN"
if [ ! -z "$2" ]; then
  DOMAIN="$2.$DOMAIN"
fi

user

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
