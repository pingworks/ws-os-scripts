#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/config.sh
. $SCRIPTDIR/common.sh

basedir=$(dirname $0)

function usage {
  local msg=$1
  echo
  echo $msg
  echo
  echo "Usage: $0"
  exit 1
}

set -e

setup_basics
setup_docker_imgs "$IMAGES" "$COMPUTE_NODES"
setup_glance_imgs "$IMAGES"

setup_users pingworks
setup_pingworks_envs

read "Create users and user envs? " foo

usernames=$(cd $COOKBOOK_BASE/keystore; ls | grep -vE '(.pub|pingworks|testuser)')
setup_users $usernames
setup_user_envs $usernames
