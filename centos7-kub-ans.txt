[LINKS]
https://github.com/mor-sergei/schebotkin
https://dashboard-trial5.client.metacloud.net/project/instances/
https://github.com/kubernetes/kubernetes/blob/master/docs/devel/api-conventions.md
http://kubernetes.io/v1.0/docs/user-guide/walkthrough/k8s201.html
https://github.com/CiscoCloud/cis-paas/issues/60
https://github.com/CiscoCloud/kubernetes-ansible

[SSh KEYs]
$ ssh-keygen -t rsa -b 4096 -C "scheb@softserveinc.com"
copy .ssh/id_rsa.pub to nodes .ssh/authorized_keys

[Deployment]
$ sudo yum install bash-completion [OPTIANAL]
$ sudo yum install unzip wget curl mc git vim ansible python-netaddr
$ mkdir download project
$ git clone https://github.com/CiscoCloud/kubernetes-ansible
$ sudo mv /etc/ansible/hosts /etc/ansible/hosts.example
$ sudo touch /etc/ansible/hosts
$ sudo chown -R cloud:cloud /etc/ansible/
$ vim /etc/ansible/hosts

	[masters]sters]
	scheb-kub-01

	[nodes]
	scheb-kub-0[2:3]

	[cluster]
	scheb-kub-0[1:3]

$ ansible -m ping cluster
scheb-kub-02 | success >> {
    "changed": false,
    "ping": "pong"
}

scheb-kub-03 | success >> {
    "changed": false,
    "ping": "pong"
}

scheb-kub-01 | success >> {
    "changed": false,
    "ping": "pong"
}
$ cd /home/cloud/project/kubernetes-ansible
$ cp inventory inventory.local
$ vim inventory.local

	[role=master]
	scheb-kub-01    ansible_ssh_host=10.1.12.6
	
	[role=node]
	scheb-kub-02    ansible_ssh_host=10.1.12.8
	scheb-kub-03    ansible_ssh_host=10.1.12.9
	
$ ansible-playbook -i inventory.local setup.yml

	PLAY RECAP ********************************************************************
	scheb-kub-01               : ok=112  changed=31   unreachable=0    failed=0
	scheb-kub-02               : ok=56   changed=34   unreachable=0    failed=0
	scheb-kub-03               : ok=56   changed=34   unreachable=0    failed=0

$
$
