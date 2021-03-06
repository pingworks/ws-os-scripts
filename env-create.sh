#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/config.sh

function usage {
  local msg=$1
  echo
  echo $msg
  echo
  echo "Usage: $0 <user> <envfile> [<subdomain>] [<nova-boot-options>] [<dns-server>] [<cookbook>]"
  exit 1
}

USER=$1
if [ -z "$USER" ]; then
  usage
fi
OS_USER=$USER

ENVFILE=$2
if [ -z "$ENVFILE" -o ! -r "$ENVFILE" ]; then
  usage "Envfile not readable: $ENVFILE"
fi
HOSTS=( $(<$ENVFILE) )

DOMAIN="$USER.$BASEDOMAIN"
if [ ! -z "$3" ]; then
  DOMAIN="$3.$DOMAIN"
fi

KEYNAME="$USER"

user
get keypair $KEYNAME >/dev/null || usage "Keypair not available: $KEYNAME"

NOVA_BOOT_OPTS="$4"
ENV_DNS="$OS_CTRL"
if [ ! -z "$5" ]; then
  ENV_DNS=$5
fi

CB_OVERWRITE=""
if [ ! -z "$6" ]; then
  CB_OVERWRITE=$6
fi

set -e

echo "====> Creating dns zone: $DOMAIN .."
DNS_ZONE_ID=$(get_or_create domain $DOMAIN)
echo "      $DNS_ZONE_ID"
echo "====> done."
echo

mofa_params=""
for host in ${HOSTS[@]}; do
  read cname flavor image runlist cnames zone<<< "$(echo $host | tr '|' ' ')"
  read cookbook recipe <<< "$(echo $runlist | sed -e 's;::; ;g')"
  if [ ! -z "$CB_OVERWRITE" ]; then
    cookbook="$CB_OVERWRITE"
  fi

  echo "====> Checking image availability in glance: $image .."
  IMAGE_ID=$(get image $image || usage "Glance image: $image does not exist.")
  echo "      $IMAGE_ID"
  echo "====> done."
  echo

  echo "====> Starting instance: $cname, $flavor.."
  NAME=$cname.$DOMAIN
  INST_ID=$(get_or_create instance $NAME $flavor $image $zone)
  echo "      $INST_ID"
  echo "====> done."
  echo

  echo "====> Creating IP: $NAME .."
  IP=$(get ip-association $INST_ID || create ip-association $INST_ID $(create floating-ip))
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

  echo "====> Waiting for instance to become available .."
  for ((i=0;i<=30;i++)); do ping -c 1 -W 1 $IP >/dev/null && break; echo -n "."; done
  echo
  echo "====> done."
  echo

  if [ ! -z "$cookbook" -a ! -z "$recipe" ]; then
    [ ! -z "$mofa_params" ] && mofa_params="$mofa_params "
    mofa_params="${mofa_params}$NAME::::$cname::::$USER::::$cookbook::::$recipe::::$OS_USERNAME::::$OS_PASSWORD"
  fi
done

if [ ! -z "$mofa_params" ]; then
  run_in_parallel ". $SCRIPTDIR/config.sh; DOMAIN=$DOMAIN ENV_DNS=$ENV_DNS run_mofa {3} {4} {5} {6} {7} {8} {9}" "$mofa_params" 7
fi
