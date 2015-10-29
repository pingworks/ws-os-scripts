#!/bin/bash

SCRIPTDIR=$(dirname $0)
. $SCRIPTDIR/config.sh

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

delete_availability_zones

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
  user admin $USER
  domains=$(run "designate domain-list" | get_field 2 | awk '{ print length, $0 }' | sort -r -n -s | cut -d" " -f2- )
  for domain in $domains; do
    echo "      $domain"
    ID=$(get_and_delete domain ${domain%.})
  done
done
echo "====> done."
echo

echo "====> Waiting for instances to disappear: .."
admin
i=0
while [ ! -z "$(run "nova list --all-tenants 1" | get_field 2)" -a $i -lt 60 ]; do
  echo -n "."
  sleep 1
  ((i++))
done
echo
echo "====> done."
echo

echo "====> Deleting routers: .."
admin
users=$(run "neutron router-list" | get_field 2| sed -e 's;router-;;')
for USER in $users; do
  user admin $USER
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
  user admin $USER
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
  user admin $USER
  echo "      private-$USER"
  ID=$(get_and_delete net private-$USER)
done
echo "====> done."
echo

echo "====> Deleting floating-ips: .."
admin
ips=$(run "neutron floatingip-list" | get_field 1)
for IP in $ips; do
  user admin $USER
  echo "      $IP"
  ID=$(neutron floatingip-delete $IP)
done
echo "====> done."
echo

echo "====> Deleting users: .."
admin
users=$(run "openstack user list" | get_field 2  \
  | grep -vE '(nova|neutron|cinder|glance|designate|admin)')
for USER in $users; do
  echo "      $USER"
  ID=$(get_and_delete user $USER)
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

echo "====> Cleaning dnsmasq entries: .."
ssh ubuntu@compute0 "sudo sed -i \
  -e \"s;^#*address=/archive.ubuntu.com/.*$;#address=/archive.ubuntu.com/;g\" \
  -e \"s;^#*address=/rubygems.org/.*$;#address=/rubygems.org/;g\" \
  -e \"s;^#*address=/bundler.rubygems.org/.*$;#address=/bundler.rubygems.org/;g\" \
  /etc/dnsmasq.d/pingworks"
ssh ubuntu@compute0 sudo service dnsmasq restart
echo "====> done."
echo

echo "====> Rebooting nodes: .."
for node in ctrl compute1 compute2 compute0; do
  echo "      $node"
  ssh ubuntu@$node "sudo reboot"
done
echo "====> done."
echo
