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
echo "====> done."
echo

echo "====> Preparing docker images: .."
EXEC_ORIG="$EXEC"
for node in $COMPUTE_NODES; do
  echo "      Node: $node"
  EXEC="ssh ${OS_SSH_USER}@${node}"
  echo "      $DOCKER_BASE_IMG"
  ID=$($EXEC "docker images" | awk '{print "| "$1":"$2" |"}'| get_matching_field 1 $DOCKER_BASE_IMG 1) \
    || $EXEC "docker pull $DOCKER_BASE_IMG > /dev/null"
  echo "      $DOCKER_JKMASTER_IMG"
  ID=$($EXEC "docker images" | awk '{print "| "$1":"$2" |"}'| get_matching_field 1 $DOCKER_JKMASTER_IMG 1) \
    || cat $COOKBOOK_BASE/$(basename $DOCKER_JKMASTER_IMG).img.gz | $EXEC "gzip -c -d | docker load"
  echo "      $DOCKER_JKSLAVE_IMG"
  ID=$($EXEC "docker images" | awk '{print "| "$1":"$2" |"}'| get_matching_field 1 $DOCKER_JKSLAVE_IMG 1) \
    || cat $COOKBOOK_BASE/$(basename $DOCKER_JKSLAVE_IMG).img.gz | $EXEC "gzip -c -d | docker load"
  echo "      $DOCKER_FRONTEND_IMG"
  ID=$($EXEC "docker images" | awk '{print "| "$1":"$2" |"}'| get_matching_field 1 $DOCKER_FRONTEND_IMG 1) \
    || cat $COOKBOOK_BASE/$(basename $DOCKER_FRONTEND_IMG).img.gz | $EXEC "gzip -c -d | docker load"
  echo "      $DOCKER_BACKEND_IMG"
  ID=$($EXEC "docker images" | awk '{print "| "$1":"$2" |"}'| get_matching_field 1 $DOCKER_BACKEND_IMG 1) \
    || cat $COOKBOOK_BASE/$(basename $DOCKER_BACKEND_IMG).img.gz | $EXEC "gzip -c -d | docker load"
done
EXEC="$EXEC_ORIG"
echo "====> done."
echo

bash img-create.sh $DOCKER_BASE_IMG
bash img-create.sh $DOCKER_JKMASTER_IMG
bash img-create.sh $DOCKER_JKSLAVE_IMG
bash img-create.sh $DOCKER_FRONTEND_IMG
bash img-create.sh $DOCKER_BACKEND_IMG

usernames=$(cd $COOKBOOK_BASE/keystore; ls | grep -vE '(.pub|pingworks|testuser)')

i=0
bash $SCRIPTDIR/user-create.sh pingworks $i
bash $SCRIPTDIR/env-create.sh pingworks envs/phonebook-pipeline-from-jkimg
bash $SCRIPTDIR/env-create.sh pingworks envs/phonebook-testenv-from-img test01

i=1
for user in $usernames; do
  bash $SCRIPTDIR/user-create.sh $user $i
  ((i++))
done

for user in $usernames; do
  bash $SCRIPTDIR/env-create.sh $user envs/phonebook-pipeline-from-jkimg
  bash $SCRIPTDIR/env-shutdown.sh $user
done
