#!bin/bash
#----------------------------------------------------------------
#------------------NETWORK---------------------------------------

#enp0s3----10.0.0.11(host- throught hot only adapter/24 subnet)--
#enp0s8----192.186.18.1(Provider Network-configured but not used 
#---------------------------------^here due to single node config
#enp0s9----NAT Network used to get internet access(traffic In)---

export path=$(pwd)
echo $path
sleep 5
export controller="10.0.0.11"
export localhost="127.0.0.1" #Also known as loop back ID

cp hosts /etc/hosts
cp 00-installer-config.yaml /etc/netplan/00-installer-config.yaml
netplan apply
sudo dpkg --configure -a

#----------------------------------------------------------------
#------------------Pre-requisites--------------------------------
apt update
apt install crudini python3-openstackclient -y<<EOF


EOF
apt upgrade -y<<EOF


EOF
apt -y autoremove
apt -y clean

apt install ifupdown -y
apt install curl tree glances -y

#-----------------------------------------------------------------
#----------------MQ-----------------------------------------------
echo "---------------RRRabit MQ-----------"
apt -y install rabbitmq-server

rabbitmqctl add_user openstack 0penstack

rabbitmqctl set_permissions openstack ".*" ".*" ".*"



#------------------------------------------------------------------
#-----------------MYSQL--------------------------------------------
echo "------------MYSQL------------"

apt install mariadb-server python3-pymysql -y<<EOF



EOF

cp 99-openstack.cnf /etc/mysql/mariadb.conf.d/99-openstack.cnf

service mysql restart

mysql_secure_installation<<EOF
0penstack
0penstack
n
n
y
n
y
EOF

#-----------------------------------------------------------------
#----------------------memcache-----------------------------------
echo "----------MEMCACHED-----------"

apt install memcached python3-memcache -y
echo "-1 10.0.0.11" >> /etc/memcached.conf
service memcached restart


#-------------------------------------------------------------------
#-----------------------ETCD----------------------------------------

echo "------------ETCD--------------"
apt install etcd-server -y<<EOF

EOF
cat etcd.txt >>/etc/default/etcd
systemctl enable etcd
systemctl restart etcd

#-------------------------------------------------------------------
#---------------------Keystone--------------------------------------

apt update
apt -y install python3-keystone
apt -y install apache2 
apt -y install libapache2-mod-wsgi-py3
apt -y install python3-oauth2client

echo "---------Creating DB for Keystone-------------"
#----------------DB for keystone---------------------
#mysql -u root -p $pass "CREATE DATABASE keystone;"
#mysql -u root -p $pass "GRANT ALL PRIVILAGES ON keystone.* TO 'keystone'@'controller' IDENTIFIED BY '0penstack';"

#mysql -u root -p $pass "GRANT ALL PRIVILAGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '0penstack';"

sudo crudini --set /etc/keystone/keystone.conf oslo_messaging_rabbit rabbit_host open

mysql<<EOF
create database keystone;
create user 'keystone'@'controller' identified by '0penstack';
GRANT ALL PRIVILAGES ON * . * TO 'keystone'@'controller';
create user 'keystone'@'%' identified by '0penstack';
GRANT ALL PRIVILAGES ON * . * TO 'keystone'@'%';
flush previlages;
exit
EOF

echo "-----------Editing keystone mysql config-----------"
crudini --set /etc/keystone/keystone.conf database connection mysql+pymysql://keystone:0penstack@controller/keystone
crudini --set /etc/keystone/keystone.conf token provider fernet

sleep 35
# Configure RabbitMQ----------------------------------------------------------------------

echo "--------------Keystone and fernet bootstrap----------------"

keystone-manage db_sync


keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone

keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

keystone-manage bootstrap --bootstrap-password 0penstack --bootstrap-admin-url http://controller:5000/v3/ --bootstrap-internal-url http://controller:5000/v3/ --bootstrap-public-url http://controller:5000/v3/ --bootstrap-region-id RegionOne

sleep 35
#-----------Apache Setup-------------------
echo "------------------Apache Setup--------------------"

cp /etc/apache2/apache2.conf /etc/apache2/apache2.conf.orig
cp /etc/apache2/sites-available/000-default.conf /etc/apache2/sites-available/000-default.conf.orig
echo "ServerName controller\nDocumentRoot /var/www/html" >>/etc/apache2/sites-available/000-default.conf

cp wsgi-keystone.conf /etc/apache2/sites-available/wsgi-keystone.conf

a2enmod wsgi
a2ensite wsgi-keystone
service apache2 restart

rm -f /var/lib/keystone/keystone.db

#-------------Generating RC File------------------------
echo "------------------generating rc file-------------------"
cd $path

export OS_USERNAME=admin
export OS_PASSWORD=0penstack
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Defaut
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OSP1='\u\h \W(keystone)\$ '
. ./keystonerc


#RC file can be use by running[ . keystonerc]

#-----------Verifying Installarion of keyston and perfoming actions-----------------

openstack --os-auth-url http://controller:5000/v3 --os-poject-domain-name default --os-user-domain-name Default --os-project-name admin --os-username admin token issue

openstack project create --domain default --description "Service Project" service
openstack project create --domain default --description "Demo Project" demo 
openstack user create --domain default --password 0penstack demo
openstack role create user
openstack role add --project demo --user demo user

#--------------------------------------------------------------------------------
#-------------------------------GLANCE SETUP-------------------------------------

echo "--------------------------SETUP GLANCE ENVIRONMENT--------------------------------"

echo "------------Configure database for Glance-------------"


mysql<<EOF
create database glance;
grant all privilages on glance.* to 'glance'@'controller' identified by '0penstack';
grant all privilages on glance.* to 'glance'@'%' identified by '0penstack';
flush previlages
exit
EOF
#mysql -u root -p -e "GRANT ALL PRIVILAGES ON glance.* TO 'glance'@'localhost'IDENTIFIED BY '0penstack';"
#mysql -u root -p -e "GRANT ALL PRIVILAGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '0penstack'"

echo "------------------GLANCE USER-----------------------"

. ./keystonerc

openstack user create --domain default --password 0penstack glance
openstack role add --project serice --user glance admin
openstack service create --name glance --description "Openstack Image" image

echo "----------------Glance Endpoints--------------------"

openstack endpoint create --region RegionOne image public http://controller:9292
openstack endpoint create --region RegionOne image internal http://controller:9292
openstack endpoint create --region RegionOne image admin http://controller:9292

echo "-----------Installing Glance and Glance Config-------------"
apt update
apt install glance -y

mv /etc/glance/glance-api.conf /etc/glance/glance-api.org
cp glance-api.conf /etc/glance/glance-api.conf
cat glance-api.conf >> /etc/glance/glance-registry.conf
#^updating glance conf snd registry with values from readymade file^

chown root:glance /etc/glance/glance-api.conf

su -s /bin/bash glance -c "glance-manage db_sync"
restart glance-api
service glance-api restart
#^both are restarting the same thing, added both so one works if other fails
service glance-registry restart
enable glance-api

echo "----------Trying out Glance Image Service------------"

. ./keystonerc

wget http://download.cirros-cloud.net/0.3.5/cirro-0.3.5-x86_64-disk.img

openstack image create cirros3.5 --file cirros-0.3.5-x86_64.img --disk-format qcow2 --controller-format bare --public
openstack image list

#--------------------------------------------------------------------------
#---------------------------SETTING UP NOVA ENV----------------------------

echo "--------------Installing Nova-------------------------------"
sudo apt install -y nova-api nova-conductor nova-consoleauth nova-novncproxy nova-scheduler nova-placement-api nova-compute python3-novaclient<<EOF


EOF

. keystonerc

echo "------creating essential credentials and previlages in openstack------"
openstack user create --domain default --project service --password 0penstack nova
openstack role add --project service --user nova admin
openstack user create --domain default --project service --password 0penstack placement
openstack service create --name nova --description "Openstack compute service" compute
openstack service create --name placement --description "Openstack Compute Placement service" placement
export controller=10.0.0.1

openstack endpoint create --region RegionOne compute public http://controller:8774/v3/%\(tenant_id\)s
openstack endpoint create --region RegionOne compute admin http://controller:8774/v3/%\(tenant_id\)s
openstack endpoint create --region RegionOne placement public http://controller:8778/
openstack endpoint create --region RegionOne Placement internal https://controller:8778/
openstack endpoint create --region RegionOne placement admin http://controller:8778/


echo "-----------MYSQl CONFIG---------------"
mysql<<EOF
create database nova;
create user 'nova'@'controller' identified by '0penstack';
grant all privilages on nova.* to 'nova'@'localhost';
create user 'nova'@'%' identified by '0penstack';
grant all previlages on nova.* to 'nova'@'%';
create database nova_api;
grant all privilages on nova_api.* to nova@'localhost' identified by 'password';
grant all privilages on nova_api.* to nova@'%' identified by 'password';
create database placement;
grant all privilages on placement.* to placement@'locahost' identified by 'password';
grant all privilages on placement.* to placement@'%' identified by 'password';
create database nova_cell0.* to nova@'localhost' identified by password;
grant ll privilages on nova_cell0.* to nova@'%' identified by 'password';
flush privilages;
exit
EOF

echo "----------------------Configure Nova---------------------"

mv /etc/nova/nova.conf /etc/nova/nova.conf.org
chmod 640 /etc/nova/nova.conf
mv nova.conf /etc/nova/.

#-----------placement config-------------------

chgrp nova /etc/nova/nova.conf
mv /etc/placement/placement.conf /etc/placement/placement.conf.org
mv placement.conf /etc/placement/placement.conf

#-----------placement api listen--------------

mv /etc/apache2/sites-enabled/placement-api.conf placement-api.bck

touch placement-api.conf

#Replacing listen endpoint in line 1
sed '1 c\
	Listen 127.0.0.1:8778' placement-api.conf

cp placement-api.conf /etc/apache2/sites-enabled/placement-api.conf

chgrp placement /etc/placement/placement.conf

#--------------------------------------------------
#---Glance API----

cat proxy-nginx >> /etc/nginx/nginx.conf

su -s /bin/bash placement -c "placement-manage db sync"

su -s /bin/bash nova -c "nova-manage api_db sync"
su -s /bin/bash nova -c "nova-manage cell_v2 map_cell0"
su -s /bin/bash nova -c "nova-manage db sync"
su -s /bin/bash nova -c "nova-manage cell_v2 create_cell --name cell1"


systemctl restart nova-api nova-cunductor nova-scheuler nova-novncproxy
systemctl enable nova-api nova-conductor nova-scheduler nova-novncproxy
systemctl restart apache2 nginx

#---------check status-------------------------
openstack compute service list

#----------KVM Compute-------------------------

apt -y install nova-compute nova-compute-kvm

cat nova-vnc >> /etc/nova/nova.conf

systemctl restart nova-compute

su -s /bin/bash nova -c "nova-manage cell_v2 discover_hosts"

#-------check compute status---------------------

openstack compute service list

#-----------------------------------------------------------------
#------------------Neutron----------------------------------------

#------creating neutron ID------------------
openstack user create --domain default --project service --password 0penstack
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "openstack networking service" network
export controller=10.0.0.1
openstack endpoint create -region RefionOne netork public http://10.0.0.1:9696
openstack endpoint create --region RegionOne network internal https://10.0.0.1:9696
openstack endpoint create --region RegionOne network adminhttps://$controller:9696


#-----------------------MYSQL for neutron--------------------------

mysql<<EOF
create database neutron_ml2;
create user neutron@'localhost' identified by '0penstack';
grant all privilages on neutron_ml2.* to neutron@'localhost';
create user neutron@'%' identified by 'password;
grant all privilages on neutron_ml2.* to neutron@'%';
flush privilages;
exit
EOF

#-------------------------install neutron------------------------
apt -y install neutron-server neutron-plugin-ml2 neutron-ovn-metadata-agent python3-neutronclient ovn-central ovn-host openswitch-switch

#-----------Editing neutron config file--------------------
mv /etc/neutron/neutron.conf /etc/neutron/neutron.conf.org
mv neutron.conf /etc/neutron/neutron.conf






















sudo cp /etc/nova/nova.conf /etc/nova/nova.conf.orig

sudo crudini --set /etc/nova/nova.conf database connection "mysql+pymysql://nova:0penstack@open/nova"











