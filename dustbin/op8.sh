

echo "----------Installing nova---------------"
sudo apt install -y -o DPkg::options::=--force-confmiss --reinstall nova-common nova-api nova-conductor nova-novncproxy nova-scheduler
echo "---------------database setup---------------------"
mysql<<EOF
create database nova


create database cell0



EOF
. ./keystonerc

nova_admin_user=nova
placement_admin_user=placement
echo "------------openstack config for nova---------"

#------------- Configure components----------------------
conf=/etc/nova/nova.conf

# --------------------Configure keystone---------------
iniset_sudo $conf keystone_authtoken www_authenticate_uri h
