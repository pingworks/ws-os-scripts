#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/config.sh
. $SCRIPTDIR/common.sh

function usage {
  local msg=$1
  echo
  echo $msg
  echo
  echo "Usage: $0 <user> <subdomain> <envfile> [<nova-boot-options>]"
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

ENVFILE=$3
if [ -z "$ENVFILE" -o ! -r "$ENVFILE" ]; then
  usage "Envfile not readable: $ENVFILE"
else
  HOSTS=( $(<$ENVFILE) )
fi

KEYNAME="$USER"

user
get keypair $KEYNAME >/dev/null || usage "Keypair not available: $KEYNAME"

NOVA_BOOT_OPTS="$5"

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

  echo "====> Checking image availability in glance: $image .."
  IMAGE_ID=$(get image $image || usage "Glance image: $image does not exist.")
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
        os_url: 'http://$OS_CTRL:5000/v2.0/tokens'
        os_user: '$OS_USERNAME'
        os_pass: '$OS_PASSWORD'
        os_keyname: '$KEYNAME'
EOF
  mofa provision . -T $NAME -o $cookbook::$recipe
  cd -
  echo "====> done."
  echo
done
