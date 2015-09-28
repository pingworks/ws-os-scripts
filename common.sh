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

  if [ "$OS_USERNAME" = "$user" -a ! -z "$OS_USER_PASSWORD" ]; then
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

function get {
  local res="$1"
  local name="$2"
  local opts="$3"
  local opts2="$4"
  local cmd
  local idx_search=2
  local idx_result=1

  case "$res" in
    docker-image)
      ssh $OS_SSH_USER@$OS_CTRL "docker images" | awk '{print "| "$1":"$2" |"}'| get_matching_field 1 $name 1
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
    keypair)
      cmd="nova keypair-list"
      idx_search=1
      ;;
    project)
      cmd="openstack project list"
      ;;
    user)
      cmd="openstack user list"
      ;;
    role-association)
      cmd="openstack role list --user $opts --project $opts2"
      ;;
    net)
      cmd="neutron net-list"
      ;;
    subnet)
      cmd="neutron subnet-list"
      ;;
    router)
      cmd="neutron router-list"
      ;;
    interface)
      cmd="neutron router-port-list $name"
      run " $cmd" | awk -F'[ \t]*\\|[ \t]*' "{ if(/ip_address/) { print \$2 } }" | grep -v '^$'
      return $?
      ;;
    gateway)
      cmd="neutron router-port-list $opts"
      idx_search=4
      ;;
    port)
      cmd="neutron port-list"
      ;;
    secgroup)
      cmd="nova secgroup-list-rules $name"
      run " $cmd" | grep "$(join '.*|.*' $opts)" >/dev/null && echo $opts
      return $?
      ;;
    flavor)
      cmd="nova flavor-list"
      ;;
    *)
      echo "Function get, unkown resource: $res"
      exit 1
      ;;
  esac
  run " $cmd" | get_matching_field $idx_search $name $idx_result
  return $?
}

function create {
  local res="$1"
  local name="$2"
  local opts="$3"
  local opts2="$4"
  local opts3="$5"
  local cmd
  local idx_search=1
  local match="id"
  local idx_result=2

  case "$res" in
    docker-image)
      ssh $OS_SSH_USER@$OS_CTRL "docker pull $name"
      return $?
      ;;
    image)
      cmd="glance image-create"
      opts="--is-public true --container-format docker --disk-format raw --name"
      run "docker save $name | OS_AUTH_URL=$OS_AUTH_URL OS_USERNAME=$OS_USERNAME OS_PASSWORD=$OS_PASSWORD OS_TENANT_NAME=$OS_TENANT_NAME  $cmd $opts $name" | get_matching_field 1 id 2
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
      run "$cmd $opts $name" && echo $name
      return $?
      ;;
    keypair)
      cmd="nova keypair-add"
      opts="--pub-key $opts"
      run "$cmd $opts $name" && echo $name
      return $?
      ;;
    project)
      cmd="openstack project create"
      ;;
    user)
      cmd="openstack user create"
      opts="--password $opts"
      ;;
    role-association)
      cmd="openstack role add"
      opts="--user $opts --project $opts2"
      ;;
    net)
      cmd="neutron net-create"
      opts="--tenant_id $opts"
      ;;
    subnet)
      cmd="neutron subnet-create"
      opts="--tenant_id $opts --ip_version 4 --gateway 10.0.$opts3.1 --name $name $opts2 10.0.$opts3.0/24"
      name=""
      ;;
    router)
      cmd="neutron router-create"
      opts="--tenant_id $opts"
      ;;
    interface)
      cmd="neutron router-interface-add"
      run "$cmd $name $opts" >/dev/null && echo $name
      return $?
      ;;
    gateway)
      cmd="neutron router-gateway-set"
      run "$cmd $opts $name" >/dev/null && echo $name
      return $?
      ;;
    port)
      cmd="neutron port-create"
      tmp="$opts"
      opts="$name"
      name="$tmp"
      opts="--name $opts"
      ;;
    secgroup)
      cmd="nova secgroup-add-rule $name"
      run "$cmd $opts" > /dev/null && echo $opts
      return $?
      ;;
    *)
      echo "Function create, unkown resource: $res"
      exit 1
      ;;
  esac
  run "$cmd $opts $name" | get_matching_field $idx_search $match $idx_result
  return $?
}

function update {
  local res="$1"
  local name="$2"
  local opts="$3"
  local opts2="$4"
  local opts3="$5"
  local cmd
  local idx_search=1
  local match="id"
  local idx_result=2

  case "$res" in
    record)
      cmd="designate record-update"
      opts="--data $opts --type $opts2 $opts3"
      ;;
    *)
      echo "Function update, unkown resource: $res"
      exit 1
      ;;
  esac
  run "$cmd $opts $name" | get_matching_field $idx_search $match $idx_result
  return $?
}

function delete {
  local res="$1"
  local name="$2"
  local opts="$3"
  local opts2="$4"
  local cmd

  case "$res" in
    image)
      cmd="glance image-delete"
      ;;
    instance)
      cmd="nova delete"
      ;;
    domain)
      cmd="designate domain-delete"
      ;;
    record)
      cmd="designate record-delete"
      ;;
    keypair)
      cmd="nova keypair-delete"
      ;;
    project)
      cmd="openstack project delete"
      ;;
    user)
      cmd="openstack user delete"
      ;;
    role-association)
      cmd="openstack role remove"
      opts="--user $opts --project $opts"
      ;;
    router)
      cmd="neutron router-gateway-clear"
      run "$cmd $name" >/dev/null
      if [ ! -z "$opts" ]; then
        cmd="neutron router-interface-delete"
        run "$cmd $name $opts" >/dev/null
      fi
      cmd="neutron router-delete"
      opts=""
      ;;
    subnet)
      cmd="neutron subnet-delete"
      ;;
    net)
      cmd="neutron net-delete"
      ;;
    flavor)
      cmd="nova flavor-delete"
      ;;
    *)
      echo "Function delete, unkown resource: $res"
      exit 1
      ;;
  esac
  run "$cmd $opts $name" >/dev/null
  return $?
}

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
    keyfiles="pingworks/.ssh/id_rsa.pub"
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
