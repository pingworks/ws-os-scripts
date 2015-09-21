#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/common.sh

OS_USER="ubuntu"
OS_CTRL="10.33.0.10"
EXEC="ssh ${OS_USER}@${OS_CTRL}"
COOKBOOK_BASE="$HOME/workspaces/cd-workshop"
KEYNAME="pingworks"
HOSTS=("jkmaster|m1.tiny|pingworks/docker-ws-baseimg:0.2|ws-env-pipeline::jkmaster|dash;repo;git" "jkslave1|m1.tiny|pingworks/docker-ws-baseimg:0.2|ws-env-pipeline::jkslave|")
#HOSTS=("jkmaster|m1.tiny|pingworks/docker-ws-jkmaster:0.1|ws-env-pipeline::jkmaster|dash;repo;git" "jkslave1|m1.tiny|pingworks/docker-ws-jkslave:0.1|ws-env-pipeline::jkslave|")
DOMAIN="ws.pingworks.net"

if [ ! -z "$1" ]; then
  DOMAIN="$1.$DOMAIN"
fi
NOVA_BOOT_OPTS="$2"

set -e

echo "====> Creating dns zone: $DOMAIN .."
DNS_ZONE_ID=$(get_or_create domain $DOMAIN)
echo "      $DNS_ZONE_ID"
echo "====> done."
echo

for host in ${HOSTS[@]}; do
  read cname flavor image runlist cnames <<< "$(echo $host | tr '|' ' ')"
  read cookbook recipe <<< "$(echo $runlist | sed -e 's;::; ;g')"

  echo "====> Pulling docker image: $image .."
  DOCKER_IMG=$(get_or_create docker-image $image)
  echo "      $DOCKER_IMG"
  echo "====> done."
  echo

  echo "====> Saving image to glance: $image .."
  IMAGE_ID=$(get_or_create image $image)
  echo "      $IMAGE_ID"
  echo "====> done."
  echo

  echo "====> Starting instance: $cname, $flavor.."
  NAME=$cname.$DOMAIN
  INST_ID=$(get_or_create instance $NAME $flavor $image)
  echo "      $INST_ID"
  echo "====> done."
  echo

  echo "====> Creating IP: $NAME .."
  IP=$(get ip-association $INST_ID || create ip-association $INST_ID $(get_or_create floating-ip))
  echo "      $IP"
  echo "====> done."
  echo

  echo "====> Creating DNS record: $NAME .."
  DNS_RECORD=$(get record $NAME $DNS_ZONE_ID) && update record $DNS_RECORD $IP A $DNS_ZONE_ID >/dev/null \
    || DNS_RECORD=$(create record $NAME $IP A $DNS_ZONE_ID)
  echo "      $DNS_RECORD"
  echo "====> done."
  echo

  echo "====> Creating DNS CNAME record: $NAME .."
  for CNAME in $(echo $cnames | tr ';' ' '); do
    DNS_RECORD=$(get record $CNAME.$DOMAIN $DNS_ZONE_ID) && update record $DNS_RECORD $NAME. CNAME $DNS_ZONE_ID >/dev/null \
      || DNS_RECORD=$(create record $CNAME.$DOMAIN $NAME. CNAME $DNS_ZONE_ID)
    echo "      $CNAME => $DNS_RECORD"
  done
  echo "====> done."
  echo

  echo "====> Provisioning $NAME with $cookbook::$recipe.."
  cd $COOKBOOK_BASE/chef-$cookbook
  cat << EOF > .mofa.local.yml
---
roles:
  - name: ${cname/[0-9]/}
    attributes:
      ws-base:
        cname: '$cname'
        domain: '$DOMAIN'
        dns: '$OS_CTRL'
EOF
  mofa provision . -T $NAME -o $cookbook::$recipe
  cd -
  echo "====> done."
  echo
done
