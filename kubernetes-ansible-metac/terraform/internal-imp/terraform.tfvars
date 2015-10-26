#59-325d103f37a4 Complete the required configuration below and copy this file and
# openstack.sample.tf or openstack-floating.sample.tf to the root directory
# before running terraform commands

# Configuration variables

auth_url = "http://api-trial5.client.metacloud.net:5000/v2.0"
tenant_id = "6cbba9609e3649ed95564a7d4b43e8b3"
tenant_name = "Cisco PaaS"
keypair_name = "sch-kub-tst"
public_key = "authorized_keys"
cluster_name = "sch-kub-tst"
image_name = "CoreOS-766.4.0"
master_flavor = "m1.medium"
node_flavor = "m1.medium"
master_count = "1"
node_count = "3"
datacenter = "Meta-Cloud"
glusterfs_volume_size = "63"
net_id = "4f7543ae-0eab-4c87-b576-c77d5c18064d"
#floating_pool = "nova"
#external_net_id = "sch-kub-tst"
