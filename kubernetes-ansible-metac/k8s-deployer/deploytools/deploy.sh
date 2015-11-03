#! /bin/bash
/deploytools/callbacks.py --stage pre-deploy --status PENDING --no-api
# Build the pre-deploy config
envtpl < /deploytools/templates/pre-deploy.conf.tpl > /deploytools/pre-deploy/pre-deploy.conf
# Call pre-deploy checks
/deploytools/pre-deploy/pre-deploy.py -c /deploytools/pre-deploy/pre-deploy.conf -l 1

if [ "$?" != "0" ]; then
  echo "Failed Pre-deploy checks"
  /deploytools/callbacks.py --stage pre-deploy --status FAILURE --data "Pre-deploy checks failed" --no-api
  exit 1
else
  /deploytools/callbacks.py --stage pre-deploy --status SUCCESS --no-api
fi

# Set base deploy path
DEPLOY_ROOT="/.private"

#Export keypair to file
#envtpl < /deploytools/templates/gluon-root.pub.tpl > /.private/gluon-root.pub

# Download deployment scripts
git clone https://github.com/CiscoCloud/kubernetes-ansible.git ${DEPLOY_ROOT}/kubernetes
/deploytools/callbacks.py --stage deploy-infra --status PENDING --no-api

# Build out the terraform config
envtpl < templates/terraform.tfvars.tpl > ${DEPLOY_ROOT}/kubernetes/terraform.tfvars
/deploytools/callbacks.py --stage deploy-infra --status PENDING --no-api

echo "-- Excuting Terraform:"
export OS_USERNAME=${DEP_CONFIGURATION_0_SPEC_PROVIDER_0_SPEC_AUTH_USERNAME}
export OS_PASSWORD="${DEP_CONFIGURATION_0_SPEC_PROVIDER_0_SPEC_AUTH_PASSWORD}"
cd ${DEPLOY_ROOT}/kubernetes && cp terraform/openstack-floating.sample.tf terraform.tf
terraform get
if [ "$?" != "0" ]; then
  echo "Deployment Failed."
  /deploytools/callbacks.py --stage deploy-infra --status FAILURE --data "Deploy Failure at terraform get" --no-api
  exit 1
fi
terraform plan
if [ "$?" != "0" ]; then
  echo "Deployment Failed."
  /deploytools/callbacks.py --stage deploy-infra --status FAILURE --data "Deploy Failure at terraform plan" --no-api
  exit 1
fi
terraform apply
if [ "$?" != "0" ]; then
  echo -e "Deployment Failed. Running terraform destroy"
  terraform destroy --force
  /deploytools/callbacks.py --stage deploy-infra --status FAILURE --data "Deploy Failure at terraform apply" --no-api
  exit 1
fi
/deploytools/callbacks.py --stage deploy-infra --status PENDING --no-api --state ${DEPLOY_ROOT}/kubernetes/terraform.tfstate

echo "-- Trigger Ansible"
export ANSIBLE_HOST_KEY_CHECKING=False
ansible all --private-key ${DEPLOY_ROOT}/private.key -i plugins/inventory/terraform.py -c local -m wait_for -a "port=22 host={{ ansible_ssh_host}} search_regex=OpenSSH delay=60"
ansible all --private-key ${DEPLOY_ROOT}/private.key -i plugins/inventory/terraform.py -m authorized_key -a "user={{ansible_ssh_user}} key='$DEP_CONFIGURATION_0_SPEC_PROVIDER_0_SPEC_PUBLIC_KEY'"
ansible-playbook --private-key ${DEPLOY_ROOT}/private.key -i plugins/inventory/terraform.py setup.yml
if [ "$?" != "0" ]; then
  echo -e "Deployment Failed. Running \'terraform destroy\'"
  terraform destroy --force
  /deploytools/callbacks.py --stage deploy-ansible --status FAILURE --data "Deploy Failure at ansible play" --no-api
  exit 1
fi
/deploytools/callbacks.py --stage deploy-ansible --status SUCCESS --no-api

echo "-- Ansible run finished, wait 5min and destroy"

/deploytools/post-deploy/postdep-chk.sh

sleep 30
terraform destroy --force
echo "-- Done"
