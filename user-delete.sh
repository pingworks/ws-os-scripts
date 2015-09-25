#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/config.sh
. $SCRIPTDIR/common.sh

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

echo "====> Deleting user: $USER .."
USER_ID=$(get_and_delete user $USER)
echo "====> done."
echo

echo "====> Deleting project: $PROJECT .."
PROJECT_ID=$(get_and_delete project $PROJECT)
echo "====> done."
echo
