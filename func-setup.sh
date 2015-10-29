#!/bin/bash

function setup_basics {
  echo "====> Deleting cirros images: .."
  admin
  for img in cirros-0.3.2-x86_64-uec cirros-0.3.2-x86_64-uec-ramdisk cirros-0.3.2-x86_64-uec-kernel; do
    echo "      $img"
    get_and_delete image $img
  done
  echo "====> done."
  echo

  echo "====> Deleting demo networking components: .."
  admin
  PRIV_SUBNET_ID=$(get subnet private-subnet || true)
  echo "      router1"
  get_and_delete router router1 $PRIV_SUBNET_ID
  echo "      private-subnet"
  get_and_delete subnet private-subnet
  echo "      private"
  get_and_delete net private
  echo "====> done."
  echo

  echo "====> Deleting existing flavors and creating default: .."
  admin
  for flv in tiny small medium large xlarge; do
    echo "      m1.$flv"
    get_and_delete flavor m1.$flv
  done
  OUT=$(get flavor default) || OUT=$(run "nova flavor-create --is-public True default 1 512 2 1")
  OUT=$(get flavor medium) || OUT=$(run "nova flavor-create --is-public True medium 2 1024 2 1")
  echo "====> done."
  echo
}

function setup_availability_zone {
  local zone="$1"
  local members="$2"
  local member

  delete_availability_zones

  echo "====> Creating availability-zone $zone: .."
  admin
  ID=$(get_or_create aggregate $zone $zone)
  for member in $members; do
    echo "      Member: $member"
    ID=$(get_or_create aggregate-host $zone $member)
  done
  echo "====> done."
  echo
}

function setup_docker_hub_imgs {
  local images="$1"
  local nodes="$2"
  local EXEC=""
  echo "====> Pulling docker images: .."
  for node in $nodes; do
    echo "      Node: $node"
    EXEC="ssh ${OS_SSH_USER}@${node}"
    for img in $images; do
      echo "      $img"
      ID=$($EXEC "docker images" | awk '{print "| "$1":"$2" |"}'| get_matching_field 1 $img 1) \
        || $EXEC "docker pull $img > /dev/null"
    done
  done
  echo "====> done."
  echo
}

function setup_docker_imgs {
  local images="$1"
  local nodes="$2"
  local EXEC=""
  echo "====> Preparing docker images: .."
  for node in $nodes; do
    echo "      Node: $node"
    EXEC="ssh ${OS_SSH_USER}@${node}"
    for img in $images; do
      echo "      $img"
      ID=$($EXEC "docker images" | awk '{print "| "$1":"$2" |"}'| get_matching_field 1 $img 1) \
        || cat $COOKBOOK_BASE/$(basename $img).img.gz | $EXEC "gzip -c -d | docker load"
    done
  done
  echo "====> done."
  echo
}

function setup_glance_imgs {
  local images="$1"
  for img in $images; do
    bash img-create.sh $img
  done
}

function setup_users {
  local usernames="$1"
  local net=$2
  local netdigit=0

  if [ -z "$net" ]; then
    net=3
  fi
  local params=""
  for user in $usernames; do
    if [ "$user" = "infra" ]; then
      netdigit=0
    elif [ "$user" = "demo" ]; then
      netdigit=1
    elif [ "$user" = "pingworks" ]; then
      netdigit=2
    else
      netdigit=$net
    fi
    [ ! -z "$params" ] && params="$params "
    params="$params$user::::$netdigit"
    ((net++))
  done
  run_in_parallel "bash $SCRIPTDIR/user-create.sh {3} {4}" "$params"
}

function setup_mirror_env {

  setup_availability_zone compute0 compute0

  set -x
  bash $SCRIPTDIR/env-create.sh infra envs/mirrors "" "--availability-zone compute0" "8.8.8.8"
  set +x

  user infra
  echo "====> Mounting apt-mirror volume: .."
  INST_ID=$(get instance apt-mirror.infra.ws.net)
  ssh ubuntu@compute0 sudo docker-mount.sh nova-$INST_ID /data2/apt-mirror-ubuntu1404 /var/spool/apt-mirror
  echo "====> done."
  echo

  echo "====> Updating dnsmasq: .."
  IP=$(get ip-association $INST_ID)
  ssh ubuntu@compute0 "sudo sed -i -e \"s;^#*address=/archive.ubuntu.com/.*$;address=/archive.ubuntu.com/$IP;g\" /etc/dnsmasq.d/pingworks"
  ssh ubuntu@compute0 sudo service dnsmasq restart
  echo "====> done."
  echo

  echo "====> Mounting gem-mirror volume: .."
  INST_ID=$(get instance gem-mirror.infra.ws.net)
  ssh ubuntu@compute0 sudo docker-mount.sh nova-$INST_ID /data2/gem-mirror /data/rubygems
  echo "====> done."
  echo

  echo "====> Updating dnsmasq: .."
  IP=$(get ip-association $INST_ID)
  ssh ubuntu@compute0 "sudo sed -i \
    -e \"s;^#*address=/rubygems.org/.*$;address=/rubygems.org/$IP;g\" \
    -e \"s;^#*address=/api.rubygems.org/.*$;address=/api.rubygems.org/$IP;g\" \
    -e \"s;^#*address=/bundler.rubygems.org/.*$;address=/bundler.rubygems.org/$IP;g\" \
    /etc/dnsmasq.d/pingworks"
  ssh ubuntu@compute0 sudo service dnsmasq restart
  echo "====> done."
  echo
}

function setup_pingworks_envs {
  setup_availability_zone performance "ctrl compute0"

  run_in_parallel "bash $SCRIPTDIR/env-create.sh {3} {4} {5}" "demo::::envs/phonebook-pipeline-from-jkimg:::: demo::::envs/phonebook-testenv-from-img::::test01 pingworks::::envs/phonebook-pipeline-from-jkimg::::"
}

function setup_single_user_env {
  local user=$1

  bash $SCRIPTDIR/env-create.sh $user envs/phonebook-pipeline-from-jkimg dev
  bash $SCRIPTDIR/env-shutdown.sh $user
}

function setup_user_envs {
  local usernames="$1"

  setup_availability_zone performance "ctrl compute0"
  run_in_parallel "bash $SCRIPTDIR/env-create.sh {3} envs/phonebook-pipeline-from-jkimg; bash $SCRIPTDIR/env-shutdown.sh {3}" "$usernames"
}
