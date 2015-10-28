#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/func-basic.sh
. $SCRIPTDIR/func-crud.sh
. $SCRIPTDIR/func-setup.sh

function get_or_create {
  local res="$1"
  local name="$2"
  local opts="$3"
  local opts2="$4"
  local opts3="$5"
  get "$res" "$name" "$opts" "$opts2" || create "$res" "$name" "$opts" "$opts2" "$opts3"
}

function get_and_delete {
  local res="$1"
  local name="$2"
  local opts="$3"
  local opts2="$4"
  id=$(get "$res" "$name" "$opts" "$opts2") || true
  if [ ! -z "$id" ]; then
    delete "$res" "$id" "$opts" "$opts2"
  fi
  return $?
}

function get_instances_in_domain {
  local domain="$1"
  local opts="$2"
  run "nova list --name .*$domain $opts"  | get_field 2 | grep $domain
}

function prepare_keyfile {
  local user="$1"
  local keyfiles=""
  cd $COOKBOOK_BASE/keystore
  keyfiles="$user/.ssh/id_rsa.pub id_rsa_jenkins.pub"
  if [ "$user" != "pingworks" ]; then
    keyfiles="$keyfiles pingworks/.ssh/id_rsa.pub"
  fi
  for file in $keyfiles; do
    if [ ! -r "$file" ]; then
      echo "Keyfile not readable: $file" >&2
      exit 1
    fi
  done
  cat $keyfiles > key.pub
}

function get_user_pwd {
  local user="$1"
  if [ ! -r "$COOKBOOK_BASE/keystore/$user/password" ]; then
    echo "Passwordfile not readable: $COOKBOOK_BASE/keystore/$user/password" >&2
    exit 1
  fi
  cat $COOKBOOK_BASE/keystore/$user/password
}

function delete_availability_zones {
  local zone
  local member

  admin
  echo "====> Deleting availability zone: .."
  for zone in $(run "nova aggregate-list" | get_field 2 | grep -vE '^(Name|)$'); do
    echo "      $zone"
    for member in $(run "nova aggregate-details $zone" | get_matching_field 2 $zone 4 | sed -e 's/, / /g' -e "s/'//g"); do
      echo "            $member"
      ID=$(delete aggregate-host $zone $member)
    done
    ID=$(delete aggregate $zone)
  done
  echo "====> done."
  echo
}
