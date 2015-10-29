#!/bin/bash

SCRIPTDIR=$(dirname ${BASH_SOURCE[0]})
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

function generate_mofa_json {
  local tmpdir="$1"
  local cname="$2"
  local user="$3"
  local cookbook_name="$4"
  local os_user="$5"
  local os_pwd="$6"

  local json
  local json2

  if [ "$cookbook_name" != "pw_base" ]; then
    json2=$(cat <<EOF
  },
  "$cookbook_name": {
EOF
)
  else
    json2=","
  fi

  json=$(cat <<EOF
{
  "pw_base": {
    "basedomain": "$BASEDOMAIN",
    "cname": "$cname",
    "domain": "$DOMAIN",
    "dns": "$ENV_DNS"
$json2
    "os_url": "http://$OS_CTRL:5000/v2.0",
    "os_user": "$os_user",
    "os_pass": "$os_pwd",
    "os_keyname": "$user"
  }
}
EOF
)
  echo "$json"
}

function run_mofa {
  local name="$1"
  local cname="$2"
  local user="$3"
  local cookbook="$4"
  local recipe="$5"
  local os_user="$6"
  local os_pwd="$7"

  local json

  echo "====> Provisioning $name with $cookbook::$recipe.."
  cookbook_name="${cookbook%@*}"
  mofa_runlist="${cookbook%@*}::$recipe"
  if echo $cookbook | grep '@' >/dev/null; then
    mofa_cookbook="$cookbook"
  else
    mofa_cookbook="$COOKBOOK_BASE/chef-$cookbook"
  fi
  json=$(generate_mofa_json "$tmpdir" "$cname" "$user" "$cookbook_name" "$os_user" "$os_pwd")
  mofa provision "$mofa_cookbook" -T "$name" -o "$mofa_runlist" -j "$json" > /tmp/mofa-$name.log 2>&1
  echo "====> done."
  echo
}
