#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/config.sh
. $SCRIPTDIR/common.sh

function usage {
  local msg=$1
  echo
  echo $msg
  echo
  echo "Usage: $0 <img-name>"
  exit 1
}

IMG=$1
if [ -z "$1" ]; then
  usage
fi

set -e

admin

echo "====> Pulling docker image: $IMG .."
DOCKER_IMG=$(get_or_create docker-image $IMG)
echo "      $DOCKER_IMG"
echo "====> done."
echo

echo "====> Saving image to glance: $IMG .."
IMAGE_ID=$(get_or_create image $IMG)
echo "      $IMAGE_ID"
echo "====> done."
echo
