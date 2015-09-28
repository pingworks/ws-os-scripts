#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/config.sh
. $SCRIPTDIR/common.sh

function usage {
  local msg=$1
  echo
  echo $msg
  echo
  echo "Usage: $0 <user> <ipnet: x>"
  exit 1
}

USER=$1
if [ -z "$USER" ]; then
  usage
fi
PROJECT=$USER
KEYPAIR=$USER

IPNET="$2"
if [ -z "$IPNET" ]; then
  usage
fi

admin

set -e

prepare_keyfile $USER
KEYFILE=$COOKBOOK_BASE/keystore/key.pub
if [ -z "$KEYFILE" -o ! -r "$KEYFILE" ]; then
  usage "Keyfile not readable: $KEYFILE"
fi

echo "====> Creating project: $PROJECT .."
PROJECT_ID=$(get_or_create project $PROJECT)
echo "      $PROJECT_ID"
echo "====> done."
echo

echo "====> Adding admin role: admin .."
ROLE_ID=$(get_or_create role-association admin admin $PROJECT)
echo "      $ROLE_ID"
echo "====> done."
echo

echo "====> Creating user: $USER .."
PASS=$USER
USER_ID=$(get_or_create user $USER $PASS)
echo "      $USER_ID"
echo "      $PASS"
echo "====> done."
echo

echo "====> Adding Member role: $USER .."
ROLE_ID=$(get_or_create role-association Member $USER $PROJECT)
echo "      $ROLE_ID"
echo "====> done."
echo

user

echo "====> Creating keypair: $KEYPAIR .."
scp -q $KEYFILE ${OS_SSH_USER}@${OS_CTRL}:pubkey.$USER
KEYPAIR_ID=$(get_or_create keypair $KEYPAIR pubkey.$USER)
echo "      $KEYPAIR_ID"
echo "====> done."
echo

echo "====> Creating private net: private-$USER .."
PRIV_NET_ID=$(get_or_create net private-$USER $PROJECT_ID )
echo "      $PRIV_NET_ID"
echo "====> done."
echo

echo "====> Creating private subnet: private-subnet-$USER .."
PRIV_SUBNET_ID=$(get_or_create subnet private-subnet-$USER $PROJECT_ID $PRIV_NET_ID $IPNET)
echo "      $PRIV_SUBNET_ID"
echo "====> done."
echo

echo "====> Creating router: router-$USER .."
ROUTER_ID=$(get_or_create router router-$USER $PROJECT_ID)
echo "      $ROUTER_ID"
echo "====> done."
echo

echo "====> Connecting router to private subnet .."
INTERFACE_ID=$(get_or_create interface $ROUTER_ID $PRIV_SUBNET_ID)
echo "      $INTERFACE_ID"
echo "====> done."
echo

echo "====> Connecting router to public subnet .."
PUB_NET_ID=$(get net public || ( echo "No public net found." && exit 1 ))
INTERFACE_ID=$(get_or_create gateway $PUB_NET_ID $ROUTER_ID)
echo "      $INTERFACE_ID"
echo "====> done."
echo

echo "====> Adding security rules .."
ID=$(get_or_create secgroup default "icmp -1 -1 0.0.0.0/0")
ID=$(get_or_create secgroup default "tcp 1 65535 0.0.0.0/0")
ID=$(get_or_create secgroup default "udp 1 65535 0.0.0.0/0")
echo "====> done."
