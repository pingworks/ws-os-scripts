#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/config.sh
. $SCRIPTDIR/common.sh

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

echo "====> Starting all instances in: $DOMAIN .."
for instance in $(get_instances_in_domain $DOMAIN "--status SHUTOFF"); do
  echo "      $instance"
  run "nova start $instance" >/dev/null
done
echo "====> done."
echo
