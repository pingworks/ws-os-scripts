#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/config.sh
. $SCRIPTDIR/common.sh

basedir=$(dirname $0)

function usage {
  local msg=$1
  echo
  echo $msg
  echo
  echo "Usage: $0"
  exit 1
}

read -p "Last chance to quit!!" ans

admin
echo "====> Deleting instances: .."
for instance in $(run "nova list --all-tenants 1" | get_field 2); do
  echo "      $instance"
  ID=$(delete instance $instance)
done
echo "====> done."
echo

echo "====> Deleting dns domains: .."
admin
users=$(run "openstack project list" | get_field 2 \
  | grep -vE '(demo|nova|neutron|cinder|glance|designate|admin|service)')
for USER in $users; do
  user
  domains=$(run "designate domain-list" | get_field 2 | awk '{ print length, $0 }' | sort -r -n -s | cut -d" " -f2- )
  for domain in $domains; do
    user
    echo "      $domain"
    ID=$(get_and_delete domain ${domain%.})
  done
done
echo "====> done."
echo

echo "====> Deleting routers: .."
admin
users=$(run "neutron router-list" | get_field 2| sed -e 's;router-;;')
for USER in $users; do
  user
  PRIV_SUBNET_ID=$(get subnet private-subnet-$USER || true)
  echo "      router-$USER"
  ID=$(get_and_delete router router-$USER $PRIV_SUBNET_ID)
done
echo "====> done."
echo

echo "====> Deleting subnets: .."
admin
users=$(run "neutron subnet-list" | get_field 2 \
  | grep 'private-subnet-' | sed -e 's;private-subnet-;;')
for USER in $users; do
  user
  echo "      private-subnet-$USER"
  ID=$(get_and_delete subnet private-subnet-$USER)
done
echo "====> done."
echo

echo "====> Deleting nets: .."
admin
users=$(run "neutron net-list" | get_field 2 \
  | grep 'private-' | sed -e 's;private-;;')
for USER in $users; do
  user
  echo "      private-$USER"
  ID=$(get_and_delete net private-$USER)
done
echo "====> done."
echo

admin
echo "====> Deleting users: .."
admin
users=$(run "openstack user list" | get_field 2  \
  | grep -vE '(demo|nova|neutron|cinder|glance|designate|admin)')
for USER in $users; do
  echo "      $USER"
  ID=$(get_and_delete USER $USER)
done
echo "====> done."
echo

echo "====> Deleting projects: .."
admin
users=$(run "openstack project list" | get_field 2 \
  | grep -vE '(demo|nova|neutron|cinder|glance|designate|admin|service)')
for USER in $users; do
  echo "      $USER"
  ID=$(get_and_delete project $USER)
done
echo "====> done."
echo
