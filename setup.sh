#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/config.sh

basedir=$(dirname $0)

function usage {
  local msg=$1
  echo
  echo $msg
  echo
  echo "Usage: $0 [<basics|pingworks|users>]"
  exit 1
}

function basics {
  setup_basics
  setup_docker_hub_imgs "$DOCKER_HUB_IMAGES" "$COMPUTE_NODES"
  setup_docker_imgs "$IMAGES" "$COMPUTE_NODES"
  setup_glance_imgs "$DOCKER_HUB_IMAGES $IMAGES"
  setup_users infra
  setup_mirror_env
}

function pingworks {
  setup_users pingworks
  setup_pingworks_envs
}

function users {
  usernames=$(cd $COOKBOOK_BASE/keystore; ls | grep -vE '(.pub|pingworks|testuser|infra)')
  setup_users "$usernames"
  setup_user_envs "$usernames"
}

set -e

task=$1
if [ -z "$task" ]; then
  task="all"
fi

case "$task" in
  basics)
    basics
    ;;
  pingworks)
    pingworks
    ;;
  users)
    users
    ;;
  all)
    basics
    pingworks
    users
    ;;
  *)
    usage "unknown task: $task"
    ;;
esac
