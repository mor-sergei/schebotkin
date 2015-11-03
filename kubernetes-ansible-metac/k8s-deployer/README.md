#Falcon Sample Deployment Container

Example container demonstrating deployment tooling leveraging the Falcon Deployment API based on HelloWorld container

##Building the container

###Requirements
- docker

Clone the Repo
```
git@github.com:CiscoCloud/falcon-testing-deployapi.git
cd falcon-testing-deployapi/k8s-deployer
```
Build container
```
docker build -t k8sdeployer .
```

Place JSON data into ENV variable for later use:
```
MYENV="$(cat FCN_DEP_DATA.json)"
```
Run builded earlier deployer container passing needed variables:
```
docker run --rm -it -e "FCN_DEP_DATA=$TESTENV" -e "FCN_API_URL=http://173.39.244.88:8080" -e "FCN_API_USERNAME=myuser" -e "FCN_API_PASSWORD=mypass" k8sdeployer
```
This command will deploy k8s and destroy after 5 minutes (to keep tenants clean)
If you want to run commands interactively you can specify docker `CMD` as ` -t /bin/bash` which will put you into interactive shell:
```
docker run --rm -it -e "FCN_DEP_DATA=$TESTENV" -e "FCN_API_URL=http://173.39.244.88:8080" -e "FCN_API_USERNAME=myuser" -e "FCN_API_PASSWORD=mypass" k8sdeployer -t /bin/bash
```
Then you can look around and trigger deploy manually:
```
./deploy.sh
```

##To be done
- Post validation checks is missing now
- Ansible parametrisation is absent

##Known Issues
- Deployment will be destroyed after 5 minutes
