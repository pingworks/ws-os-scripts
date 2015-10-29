#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/config.sh

function usage {
  local msg=$1
  echo
  echo $msg
  echo
  echo "Usage: $0 <user>"
  exit 1
}

USER=$1
if [ -z "$USER" ]; then
  usage
fi
PROJECT=$USER
KEYPAIR=$USER

admin

set -e

PRIV_SUBNET_ID=$(get subnet private-subnet-$USER || true)
echo "====> Deleting router: router-$USER .."
USER_ID=$(get_and_delete router router-$USER $PRIV_SUBNET_ID)
echo "====> done."
echo

echo "====> Deleting subnet: private-subnet-$USER .."
USER_ID=$(get_and_delete subnet private-subnet-$USER)
echo "====> done."
echo

echo "====> Deleting net: private-$USER .."
USER_ID=$(get_and_delete net private-$USER)
echo "====> done."
echo

echo "====> Deleting user: $USER .."
USER_ID=$(get_and_delete user $USER)
echo "====> done."
echo

echo "====> Deleting project: $PROJECT .."
PROJECT_ID=$(get_and_delete project $PROJECT)
echo "====> done."
echo
