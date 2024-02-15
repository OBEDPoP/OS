#!/bin/bash
echo "yeah!"

:'

echo "----------------changing host----------------"
cd /etc/
mv hosts hosts.bck
touch host
awk ''NR!~/^(2)$/'' hosts.bck > host
file=$(cat host)
touch hosts
count=1

for p in $file; do
	if [ "$count" -eq 2 ]
	then
		echo "10.0.0.11 controller" >> hosts
	fi
	echo $p >> hosts
	count=$((count+=1))
done
rm -rf host hosts.bck

echo "-------------change network config-------------"
cd /etc/netplan/

echo "network:\n  version: 2\n  ethernets:\n    enp0s3:\n      addresses: [10.0.0.11/24]"> 00-installer-config.yaml
echo "      routes:\n        - to: default\n          via: 10.0.0.1\n      nameservers:\n        addresses: [1.1.1.1,8.8.8.8]">> 00-installer-config.yaml
echo "    enp0s8:\n      dhcp4: no\n      dhcp6: no">>00-installer-config.yaml

netplan apply


echo "---Setting as local time and installing nessacities---" 
apt install chrony glances -y
echo "#allow\nallow 10.0.0.0/24" >> /etc/chrony/chrony.conf
service chrony restart
apt install curl python3-openstackclient -y<<EOF


EOF
apt update
apt upgrade -y<<EOF


EOF
'
export GPG_TTY=$(tty)
echo "------------installig and configuring mysql------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
apt -y install mariadb-server python3-pymysql
touch /etc/mysql/mariadb.conf.d/99-openstack.cnf
echo "[mysqld]\nbind-address = 10.0.0.11\nmax_connections = 4096" > /etc/mysql/mariadb.conf.d/99-openstack.cnf

echo "------------restart-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"

service mysql restart

echo "-----------Running MYSQL_SECURE_INSTALLATION-----------"
mysql_secure_installation<<EOF

y
n
n
y
n
y
EOF

echo "---------------Installing Rabbit MQ-------------------"

apt install rabbitmq-server -y
rabbitmqctl add_user openstack openstack
rabbitmqctl set_permissions openstack ".*" ".*" ".*"

echo "--------------Configuring Memcached-------------------"

apt install memcached python3-memcache -y
echo "-1 10.0.0.11" >>/etc/memcached.conf
service memcached restart

echo "---------------Configuring ETCD-----------------------"

apt install etcd-server -y<<EOF

EOF
cat etcd.txt >>/etc/default/etcd
systemctl enable etcd
systemctl restart etcd

echo "-----------------KEYSTONE SETUP------------------------"

mysql<<EOF
create database keystone;
grant all previlages on keystone.* to keystone@'10.0.0.11' identified by '0penstack';
grant all previlages on keystone.* to keystone@'%' identified by '0penstack'
flush previlages
exit
EOF
apt -y install keystone python3-openstackclient apache2 libapache2-mod-wsgi-py3 crudini<<EOF

EOF
export controller=10.0.0.11
echo "[database]\nconnection = mysql+pymysql:keystone:0penstack@10.0.0.11\n[token]\nprovider = fernet" >> /etc/keystone/keystone.conf
su -s /bin/sh -c "keystone-manage db_sync" keystone
keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone
keystone-manage bootstrap --bootstrap-password 0penstack --bootstrap-admin-url http://10.0.0.11:5000/v3/ --bootstrap-internal-url http://10.0.0.11:5000/v3/ --bootstrap-public-url http://10.0.0.11:5000/v3/ --bootstrap-region-id RegionOne


