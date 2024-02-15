cp hosts /etc/hosts
cp 00-installer-config.yaml /etc/netplan/00-installer-config.yaml
sudo dpkg --configure -a

#----------------------------------------------------------------
#------------------Pre-requisites--------------------------------
apt update
apt install python3-openstackclient -y<<EOF


EOF
apt upgrade -y<<EOF


EOF
apt -y autoremove
apt -y clean

apt install ifupdown -y
apt install curl tree -y
#------------------------------------------------------------------
#-----------------MYSQL--------------------------------------------

rm -rf /var/lib/mysql /etc/mysql /run/mysql

apt install mariadb-server python3-pymysql -y<<EOF



EOF

cp /home/obed/OS/99-openstack.sh /etc/mysql/mariadb.conf.d/99-openstack.cnf
99-openstack.sh
service mysql restart



