# Complete the required configuration below and copy this file and
# openstack.sample.tf or openstack-floating.sample.tf to the root directory
# before running terraform commands

# Configuration variables

auth_url = "{{ DEP_CONFIGURATION_0_SPEC_PROVIDER_0_SPEC_AUTH_KEYSTONEURL }}"
tenant_id = "{{ DEP_CONFIGURATION_0_SPEC_PROVIDER_0_SPEC_AUTH_TENANTID }}"
tenant_name = "{{ DEP_CONFIGURATION_0_SPEC_PROVIDER_0_SPEC_AUTH_TENANTNAME }}"
public_key = "/.private/public.key"
keypair_name = "{{ DEP_CONFIGURATION_0_SPEC_PROVIDER_0_SPEC_KEYPAIR_NAME | default("k8s-keypair") }}"
cluster_name = "{{ DEP_CONFIGURATION_0_SPEC_PLATFORM_0_SPEC_CLUSTER_NAME | default("kubernetes") }}"
image_name = "{{ DEP_CONFIGURATION_0_SPEC_PLATFORM_0_SPEC_0_NODES_IMAGE }}"
master_flavor = "{{ DEP_CONFIGURATION_0_SPEC_PLATFORM_0_SPEC_0_NODES_FLAVOR }}"
node_flavor = "{{ DEP_CONFIGURATION_0_SPEC_PLATFORM_0_SPEC_1_NODES_FLAVOR }}"
master_count = "{{ DEP_CONFIGURATION_0_SPEC_PLATFORM_0_SPEC_0_NODES_COUNT | default("1") }}"
node_count = "{{ DEP_CONFIGURATION_0_SPEC_PLATFORM_0_SPEC_1_NODES_COUNT | default("2") }}"
datacenter = "{{ DEP_CONFIGURATION_0_SPEC_PLATFORM_0_SPEC_DATACENTER | default("openstack") }}"
floating_pool = "{{ DEP_CONFIGURATION_0_SPEC_PROVIDER_0_SPEC_FLOATING_IP_POOL }}"
external_net_id = "{{ DEP_CONFIGURATION_0_SPEC_PROVIDER_0_SPEC_EXT_NET_ID }}"
