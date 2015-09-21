#!/bin/bash

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
        echo "$data" | awk -F'[ \t]*\\|[ \t]*' "{ print $field }"
    done
}

function get {
  local res=$1
  local name=$2
  local opts="$3"
  local cmd
  local idx_search=2
  local idx_result=1

  case "$res" in
    docker-image)
      $EXEC "docker images" | awk '{print "| "$1":"$2" |"}'| get_matching_field 1 $name 1
      return $?
      ;;
    image)
      cmd="nova image-list"
      ;;
    domain)
      cmd="designate domain-list"
      name="$name."
      ;;
    instance)
      cmd="nova list"
      ;;
    record)
      cmd="designate record-list $opts"
      name="$name."
      idx_search=3
      idx_result=1
      ;;
    floating-ip)
      cmd="nova floating-ip-list"
      idx_search=3
      idx_result=2
      name="-"
      ;;
    ip-association)
      cmd="nova floating-ip-list"
      idx_search=3
      idx_result=2
      ;;
    *)
      echo "Function get, unkown res: $res"
      exit 1
      ;;
  esac
  $EXEC "~/openstack.sh demo $cmd" | get_matching_field $idx_search $name $idx_result
  return $?
}

function create {
  local res=$1
  local name=$2
  local opts="$3"
  local opts2="$4"
  local opts3="$5"
  local cmd
  local idx_search=1
  local match="id"
  local idx_result=2
  local user="demo"

  case "$res" in
    docker-image)
      $EXEC "docker pull $name"
      return 0
      ;;
    image)
      cmd="glance image-create"
      user="admin"
      opts="--is-public true --container-format docker --disk-format raw --name"
      $EXEC "docker save $name | ~/openstack.sh $OS_USER $cmd $opts $name" | get_matching_field 1 id 2
      return $?
      ;;
    domain)
      cmd="designate domain-create"
      opts="--email christoph.lukas@gmx.net --name"
      name="$name."
      ;;
    instance)
      cmd="nova boot"
      opts="$NOVA_BOOT_OPTS --flavor $opts --image $opts2 --key-name $KEYNAME"
      ;;
    record)
      cmd="designate record-create"
      name="$name."
      opts="$opts3 --data $opts --type $opts2 --name"
      ;;
    floating-ip)
      cmd="nova floating-ip-create"
      idx_search=5
      idx_result=2
      match="public"
      ;;
    ip-association)
      cmd="nova floating-ip-associate"
      tmp="$opts"
      opts="$name"
      name="$tmp"
      $EXEC "~/openstack.sh $user $cmd $opts $name" && echo $name
      return 0
      ;;
    *)
      echo "Function create, unkown res: $res"
      exit 1
      ;;
  esac
  $EXEC "~/openstack.sh $user $cmd $opts $name" | get_matching_field $idx_search $match $idx_result
  return $?
}

function update {
  local res=$1
  local name=$2
  local opts="$3"
  local opts2="$4"
  local opts3="$5"
  local cmd
  local idx_search=1
  local match="id"
  local idx_result=2
  local user="demo"

  case "$res" in
    record)
      cmd="designate record-update"
      opts="--data $opts --type $opts2 $opts3"
      ;;
    *)
      echo "Function update, unkown res: $res"
      exit 1
      ;;
  esac
  $EXEC "~/openstack.sh $user $cmd $opts $name" | get_matching_field $idx_search $match $idx_result
  return $?
}

function delete {
  local res=$1
  local name=$2
  local opts="$3"
  local opts2="$4"
  local cmd
  local user="demo"

  case "$res" in
    instance)
      cmd="nova delete"
      ;;
    domain)
      cmd="designate domain-delete"
      ;;
    record)
      cmd="designate record-delete"
      ;;
    *)
      echo "Function delete, unkown res: $res"
      exit 1
      ;;
  esac
  $EXEC "~/openstack.sh $user $cmd $opts $name"
  return $?
}

function get_or_create {
  local res=$1
  local name=$2
  local opts=$3
  local opts2=$4
  get $res $name || create $res $name $opts $opts2
}

function get_and_delete {
  local res=$1
  local name=$2
  local opts=$3
  local opts2=$4
  id=$(get $res $name) && delete $res $id
}

function get_instances_in_domain {
  local domain=$1
  $EXEC "~/openstack.sh demo nova list --name .*$domain" | get_field 2 | grep $domain
}
