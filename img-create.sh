#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/common.sh

OS_SSH_USER="ubuntu"
OS_CTRL="10.33.0.10"
EXEC="ssh ${OS_SSH_USER}@${OS_CTRL}"

function usage {
  local msg=$1
  echo
  echo $msg
  echo
  echo "Usage: $0 <subdomain> <envfile> <keyname> [<nova-boot-options>]"
  exit 1
}

IMG=$1
if [ -z "$1" ]; then
  usage
fi

set -e

OS_USER="admin"
echo -n "Openstack admin password: "; read OS_PASSWORD

echo "====> Pulling docker image: $IMG .."
DOCKER_IMG=$(get_or_create docker-image $IMG)
echo "      $DOCKER_IMG"
echo "====> done."
echo

echo "====> Saving image to glance: $IMG .."
IMAGE_ID=$(get image $IMG || usage "Glance image: $IMG does not exist.")
echo "      $IMAGE_ID"
echo "====> done."
echo
