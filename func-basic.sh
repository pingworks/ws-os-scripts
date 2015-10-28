#!/bin/bash

function join {
  local separator="$1"
  shift
  local vars=( "$@" )
  local result
  result="$( printf "${separator}%s" "${vars[@]}" )"
  result="${result:${#separator}}"
  echo $result
}

# Grab a numbered field from python prettytable output
# Fields are numbered starting with 1
# Reverse syntax is supported: -1 is the last field, -2 is second to last, etc.
# get_field field-number
function get_matching_field {
    local data field result
    local out=""
    while read data; do
        if [ "$1" -lt 0 ]; then
            field="(\$(NF$1))"
        else
            field="\$$(($1 + 1))"
        fi
        match="$2"
        if [ -z "$3" ]; then
          wanted="\$0"
        else
          wanted="\$$(($3 + 1))"
        fi
        result=$(echo "$data" | awk -F'[ \t]*\\|[ \t]*' "{ if($field==\"$match\") { print $wanted } }")
        if [ ! -z "$result" ]; then
          if [ ! -z "$3" ]; then
            echo -e "$result"
          fi
          return 0
        fi
    done
    return 1
}

function get_field {
    local data field result
    local out=""
    while read data; do
        if [ "$1" -lt 0 ]; then
            field="(\$(NF$1))"
        else
            field="\$$(($1 + 1))"
        fi
        echo "$data" | awk -F'[ \t]*\\|[ \t]*' "{ if(\$2!=\"ID\" && \$2!=\"id\") print $field }"
    done
}

function run {
  local cmd=$1

  if [ $DEBUG -ne 0 ]; then
    set -x
  fi
  out=$($EXEC "OS_AUTH_URL=$OS_AUTH_URL OS_USERNAME=$OS_USERNAME OS_PASSWORD=$OS_PASSWORD OS_TENANT_NAME=$OS_TENANT_NAME $cmd")
  if [ $DEBUG -ne 0 ]; then
    set +x
    echo -e "OUTPUT:$out"
  fi
  if [ ! -z "$out" ]; then
    echo -e "$out"
  fi
  return $?
}

function admin {
  user admin admin
}

function user {
  local user=$1
  local tenant=$2

  if [ -z "$user" -a ! -z "$USER" ]; then
    user=$USER
  fi
  if [ -z "$tenant" ]; then
    tenant=$user
  fi

  if [ "$user" = "admin" -a ! -z "$OS_ADMIN_PASSWORD" ]; then
    export OS_PASSWORD=$OS_ADMIN_PASSWORD
  elif [ "$OS_USERNAME" = "$user" -a ! -z "$OS_USER_PASSWORD" ]; then
    export OS_PASSWORD=$OS_USER_PASSWORD
  else
    if [ -r "$COOKBOOK_BASE/keystore/$user/password" ]; then
      OS_PASSWORD=$(<$COOKBOOK_BASE/keystore/$user/password)
    else
      read -s -p "Please enter the password for openstack user $user: " OS_PASSWORD
    fi
    export OS_USER_PASSWORD=$OS_PASSWORD
    echo
    echo
  fi
  export OS_USERNAME="$user"
  export OS_TENANT_NAME="$tenant"
}

function run_in_parallel {
  local task="$1"
  local params="$2"

  local table=""
  local i=1
  # add colorcodes to input params
  for set in $params; do
    ((mod=$i % 6)) || mod=6
    [ ! -z "$table" ] && table="$table\n"
    table="$table$(tput setaf $mod)::::$(tput sgr0)::::$set"
    ((i++))
  done
  echo -e "$table" | parallel -u -j $PARALLEL --colsep '::::' "set -o pipefail; ( $task ) 2>&1| sed 's/.*/{1}&{2}/'"
}
