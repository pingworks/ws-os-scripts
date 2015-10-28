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
    aggregate)
      cmd="nova aggregate-list"
      ;;
    aggregate-host)
      cmd="nova aggregate-details $name"
      ID=$(run " $cmd" | awk -F'[ \t]*\\|[ \t]*' "{ if(\$5~/'$opts'/) print \$2 }")
      test ! -z "$ID"
      return $?
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
      ssh $OS_SSH_USER@$OS_CTRL "docker save $name | OS_AUTH_URL=$OS_AUTH_URL OS_USERNAME=$OS_USERNAME OS_PASSWORD=$OS_PASSWORD OS_TENANT_NAME=$OS_TENANT_NAME  $cmd $opts $name" | get_matching_field 1 id 2
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
      if [ ! -z "$opts3" ]; then
        opts="--availability-zone $opts3 $opts"
      fi
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
    aggregate)
      cmd="nova aggregate-create"
      idx_search=2
      match="$name"
      idx_result=1
      ;;
    aggregate-host)
      cmd="nova aggregate-add-host"
      idx_search=2
      match="$name"
      idx_result=1
      tmp="$opts"
      opts="$name"
      name="$tmp"
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
    aggregate)
      cmd="nova aggregate-delete"
      ;;
    aggregate-host)
      cmd="nova aggregate-remove-host"
      tmp="$opts"
      opts="$name"
      name="$tmp"
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

function setup_basics {
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
}

function setup_availability_zone {
  local zone="$1"
  local members="$2"
  local member

  delete_availability_zones

  echo "====> Creating availability-zone $zone: .."
  admin
  ID=$(get_or_create aggregate $zone $zone)
  for member in $members; do
    echo "      Member: $member"
    ID=$(get_or_create aggregate-host $zone $member)
  done
  echo "====> done."
  echo
}

function setup_docker_hub_imgs {
  local images="$1"
  local nodes="$2"
  local EXEC=""
  echo "====> Pulling docker images: .."
  for node in $nodes; do
    echo "      Node: $node"
    EXEC="ssh ${OS_SSH_USER}@${node}"
    for img in $images; do
      echo "      $img"
      ID=$($EXEC "docker images" | awk '{print "| "$1":"$2" |"}'| get_matching_field 1 $img 1) \
        || $EXEC "docker pull $img > /dev/null"
    done
  done
  echo "====> done."
  echo
}

function setup_docker_imgs {
  local images="$1"
  local nodes="$2"
  local EXEC=""
  echo "====> Preparing docker images: .."
  for node in $nodes; do
    echo "      Node: $node"
    EXEC="ssh ${OS_SSH_USER}@${node}"
    for img in $images; do
      echo "      $img"
      ID=$($EXEC "docker images" | awk '{print "| "$1":"$2" |"}'| get_matching_field 1 $img 1) \
        || cat $COOKBOOK_BASE/$(basename $img).img.gz | $EXEC "gzip -c -d | docker load"
    done
  done
  echo "====> done."
  echo
}

function setup_glance_imgs {
  local images="$1"
  for img in $images; do
    bash img-create.sh $img
  done
}

function setup_users {
  local usernames="$1"
  local net=$2
  local netdigit=0

  if [ -z "$net" ]; then
    net=2
  fi
  for user in $usernames; do
    if [ "$user" = "infra" ]; then
      netdigit=0
    elif [ "$user" = "pingworks" ]; then
      netdigit=1
    else
      netdigit=$net
    fi
    bash $SCRIPTDIR/user-create.sh $user $netdigit
    ((net++))
  done
}

function setup_mirror_env {

  setup_availability_zone compute0 compute0

  set -x
  bash $SCRIPTDIR/env-create.sh infra envs/mirrors "" "--availability-zone compute0" "8.8.8.8"
  set +x

  user infra
  echo "====> Mounting apt-mirror volume: .."
  INST_ID=$(get instance apt-mirror.infra.ws.net)
  ssh ubuntu@compute0 sudo docker-mount.sh nova-$INST_ID /data2/apt-mirror-ubuntu1404 /var/spool/apt-mirror
  echo "====> done."
  echo

  echo "====> Updating dnsmasq: .."
  IP=$(get ip-association $INST_ID)
  ssh ubuntu@compute0 "sudo sed -i -e \"s;^#*address=/archive.ubuntu.com/.*$;address=/archive.ubuntu.com/$IP;g\" /etc/dnsmasq.d/pingworks"
  ssh ubuntu@compute0 sudo service dnsmasq restart
  echo "====> done."
  echo

  echo "====> Mounting gem-mirror volume: .."
  INST_ID=$(get instance gem-mirror.infra.ws.net)
  ssh ubuntu@compute0 sudo docker-mount.sh nova-$INST_ID /data2/gem-mirror /data/rubygems
  echo "====> done."
  echo

  echo "====> Updating dnsmasq: .."
  IP=$(get ip-association $INST_ID)
  ssh ubuntu@compute0 "sudo sed -i \
    -e \"s;^#*address=/rubygems.org/.*$;address=/rubygems.org/$IP;g\" \
    -e \"s;^#*address=/api.rubygems.org/.*$;address=/api.rubygems.org/$IP;g\" \
    -e \"s;^#*address=/bundler.rubygems.org/.*$;address=/bundler.rubygems.org/$IP;g\" \
    /etc/dnsmasq.d/pingworks"
  ssh ubuntu@compute0 sudo service dnsmasq restart
  echo "====> done."
  echo
}

function setup_pingworks_envs {
  setup_availability_zone performance "ctrl compute0"

  bash $SCRIPTDIR/env-create.sh pingworks envs/phonebook-pipeline-from-jkimg prod
  bash $SCRIPTDIR/env-create.sh pingworks envs/phonebook-testenv-from-img test01.prod
  bash $SCRIPTDIR/env-create.sh pingworks envs/phonebook-pipeline-from-jkimg dev

  set +x
}

function setup_user_envs {
  local usernames="$1"

  setup_availability_zone performance "ctrl compute0"
  for user in $usernames; do
    bash $SCRIPTDIR/env-create.sh $user envs/phonebook-pipeline-from-jkimg dev
    bash $SCRIPTDIR/env-shutdown.sh $user
  done
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
