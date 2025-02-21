**#Note: code deprecated use for reference purposes only**

This tool is being developed for usage in single node deployments of Openstack Cloudin Ubuntu 22.04 LTS Server

make sure to become root user before running this script:
sudo su

Step 1:
Clone the repo to the VM using "git Clone"

Step 2:
Go into OS folder

step 3:
chmod 700 op5.sh
run "sh op5.sh" (or) "./op5.sh
(op5 has the latest staged script, after finding and improving from issues in previous version script, and does not carry any distint meaning to openstack)

PRE-REQUISITES

1: Adapters
Since this code can be changed to be used for multi node deployment, it by default implements the network plan for Multi node Openstack deployment

Multi-node config:


+======enp0s3 controller/host node[10.0.0.11/24]==================    <br>
............||............................................................0    <br>
+===||==enp0s9 NAT for getting internet access to VM===============    <br>
............||.....||.....................................................0    <br>
+----------------+...............................................0    <br>
|.................................|...............................................0    <br>
|.....node..................|...............................................0    <br>
|.................................|...............................................0    <br>
+----------------+...............................................0    <br>
.............||....||.....................................................0    <br>
+===||=====localhost 127.0.0.1(loopback/same vm communications)===    <br>
.............||...........................................................0    <br>
+=========enp0s8 Internal Host network(Provider Network)==========    <br>

Current config:
Public......=============NAT============    <br>
Private......enp0s3 -----Node------enp0s9    <br>


Note: enp0s8 is optional if ony two adapters are configured then enp0s8 will become NAT network.

Important: the details in netplan must be changed as per no of adapters configured/available externally
the Node distributiion diagram can be seen in the "three node config.png", and "single node openstack.png" file attatched 

Fact: single node deployment can also be done with just one external host adapter(ethernet), but might not be safe to do so.


!!>>for changes to network config edit 00-in**.yaml file in op5.sh local

I have thrown in few of the many failure scripts as samples into dustbin folder incase it is needed for reference
