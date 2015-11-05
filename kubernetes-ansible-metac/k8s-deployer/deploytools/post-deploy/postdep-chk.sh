#!/bin/bash

DEPLOY_BASE=/deploytools
POST_DEPLOY_BASE=$DEPLOY_BASE/post-deploy
POST_DEPLOY_PRIVATE=$POST_DEPLOY_BASE/.private
POST_DEPLOY_SSH_KEY=/.private/private.key

SLP_TIME=10
USER_NAME=centos
SSH_OPTIONS="-t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no"

mkdir -p ${POST_DEPLOY_PRIVATE}
cp ${POST_DEPLOY_BASE}/sysctl_status_pods.mod ${POST_DEPLOY_PRIVATE}/sysctl_status_pods.mod
cp ${POST_DEPLOY_BASE}/sysctl_status_pods.mod ${POST_DEPLOY_PRIVATE}/sysctl_status_master.mod
cp ${POST_DEPLOY_BASE}/multi-main.sh ${POST_DEPLOY_PRIVATE}/multi-main.sh

# Getting list of hosts from terraform output

HOSTS_LST=`./plugins/inventory/terraform.py --list | tr -d "\"," |  awk '{for(i=1;i<=NF;i++) if ($i=="access_ip_v4:") print $(i+1)}'`

echo "+++ EXTRACTED"
echo "$HOSTS_LST"

# Get hosts name via ssh extracted from terraform output
# Parse in separate groups MASTER/PODS

MSTC=0
NODC=0

echo "---------------GETTING HOSTNAMES---------------------"
sleep $SLP_TIME
for HST in ${HOSTS_LST}
 do
  FHST=$USER_NAME@$HST
  echo "SSH REQUEST: ssh ${SSH_OPTIONS} -i ${POST_DEPLOY_SSH_KEY} ${FHST}"
  ANSWER=`ssh ${SSH_OPTIONS} -i ${POST_DEPLOY_SSH_KEY} ${FHST} 'uname -n'`
  HOSTS_CONV="$HST:$ANSWER"
  if [[ $HOSTS_CONV == *master* ]]; then echo "GOT MASTER: $HOSTS_CONV"; MASTERS[$MSTC]=$HOSTS_CONV; ((MSTC++)); fi
  if [[ $HOSTS_CONV == *node* ]]; then echo "GOT NODE: $HOSTS_CONV"; NODES[$NODC]=$HOSTS_CONV; ((NODC++)); fi
 done
echo "-----------SORTING MASTER/NODES----------------------"

for i in ${MASTERS[*]}; do echo "MASTER: ${i}"; done
for i in ${NODES[*]}; do echo "NODES: ${i}"; done

# Checkers config geniration
PODS_CONFIG=sysctl_status_pods.cfg
MASTER_CONFIG=sysctl_status_master.cfg

#-----------------------------MASTERS GENERATION------------------------------------------------------------------
NODCV=0

echo "--------------CREATING MASTERS CONFIG-----------------"
echo "# This is configure file for post deploy MASTER check" > ${POST_DEPLOY_PRIVATE}/$MASTER_CONFIG
echo "BASEDIR=${POST_DEPLOY_BASE}" >> ${POST_DEPLOY_PRIVATE}/$MASTER_CONFIG
echo "SSH_KEY=${POST_DEPLOY_SSH_KEY}" >> ${POST_DEPLOY_PRIVATE}/$MASTER_CONFIG
echo "MODULES=${POST_DEPLOY_PRIVATE}" >> ${POST_DEPLOY_PRIVATE}/$MASTER_CONFIG
echo "# Services def block" >> ${POST_DEPLOY_PRIVATE}/$MASTER_CONFIG
echo "ASYSTEMD[1]=kube-apiserver.service # Kubernetes API Server" >> ${POST_DEPLOY_PRIVATE}/$MASTER_CONFIG
echo "ASYSTEMD[2]=kube-controller-manager.service # Kubernetes Controller Manager" >> ${POST_DEPLOY_PRIVATE}/$MASTER_CONFIG
echo "ASYSTEMD[3]=kube-proxy.service # Kubernetes Kube-Proxy Server" >> ${POST_DEPLOY_PRIVATE}/$MASTER_CONFIG
echo "ASYSTEMD[4]=kube-scheduler.service # Kubernetes Scheduler Plugin" >> ${POST_DEPLOY_PRIVATE}/$MASTER_CONFIG
echo "ASYSTEMD[5]=etcd.service # Etcd Server" >> ${POST_DEPLOY_PRIVATE}/$MASTER_CONFIG
echo "ASYSTEMD[6]=flanneld.service # Flanneld overlay address etcd agent" >> ${POST_DEPLOY_PRIVATE}/$MASTER_CONFIG
echo "# MASTER name array" >> ${POST_DEPLOY_PRIVATE}/$MASTER_CONFIG

for i in ${MASTERS[*]}; do
 # echo "ADD MASTER: ${i}"
 FULL_HOST=`echo "${USER_NAME}@${i}" | cut -d':' -f1`
 echo "PODS_NAME[$NODCV]=\"$FULL_HOST\"" >> ${POST_DEPLOY_PRIVATE}/$MASTER_CONFIG
 ((NODCV++))
done
echo "MASTERS CONFIGURATION COMPLETED"
cat ${POST_DEPLOY_PRIVATE}/$MASTER_CONFIG
echo "-----------------------------------------------------"
echo

${POST_DEPLOY_PRIVATE}/multi-main.sh --path=${POST_DEPLOY_PRIVATE} --sysctl_status_master
if [ "$?" -eq "0" ]
 then echo "--------------[CHECK COMPLETED SUCCESSFULY]-----------"
  else echo "------------[CHECK HAS FAILED]-----------------------"
  exit 1
fi

echo 

#-----------------------------MASTERS GENERATION------------------------------------------------------------------

#-----------------------------NODES GENERATION--------------------------------------------------------------------
NODCV=0
echo "----------------CREATING NODES CONFIG----------------"
echo "# This is configure file for post deploy NODES check" > ${POST_DEPLOY_PRIVATE}/$PODS_CONFIG
echo "BASEDIR=${POST_DEPLOY_BASE}" >> ${POST_DEPLOY_PRIVATE}/$PODS_CONFIG
echo "SSH_KEY=${POST_DEPLOY_SSH_KEY}" >> ${POST_DEPLOY_PRIVATE}/$PODS_CONFIG
echo "MODULES=${POST_DEPLOY_PRIVATE}" >> ${POST_DEPLOY_PRIVATE}/$PODS_CONFIG
echo "# Services def block" >> ${POST_DEPLOY_PRIVATE}/$PODS_CONFIG
echo "ASYSTEMD[1]=docker.service # Docker Application Container Engine" >> ${POST_DEPLOY_PRIVATE}/$PODS_CONFIG
echo "ASYSTEMD[2]=flanneld.service # Flanneld overlay address etcd agent" >> ${POST_DEPLOY_PRIVATE}/$PODS_CONFIG
echo "ASYSTEMD[3]=kube-proxy.service # Kubernetes Kube-Proxy Server" >> ${POST_DEPLOY_PRIVATE}/$PODS_CONFIG
echo "ASYSTEMD[4]=kubelet.service # Kubernetes Kubelet Server" >> ${POST_DEPLOY_PRIVATE}/$PODS_CONFIG
echo "# NODES name array" >> ${POST_DEPLOY_PRIVATE}/$PODS_CONFIG

for i in ${NODES[*]}; do
 # echo "ADD NODE: ${i}"
 FULL_HOST=`echo "${USER_NAME}@${i}" | cut -d':' -f1`

 echo "PODS_NAME[$NODCV]=\"$FULL_HOST\"" >> ${POST_DEPLOY_PRIVATE}/$PODS_CONFIG
 ((NODCV++))
done
echo "NODES CONFIGURATION COMPLETED"
cat ${POST_DEPLOY_PRIVATE}/$PODS_CONFIG
echo "-----------------------------------------------------"
echo

${POST_DEPLOY_PRIVATE}/multi-main.sh --path=${POST_DEPLOY_PRIVATE} --sysctl_status_pods
if [ "$?" -eq "0" ]
 then echo "--------------[CHECK COMPLETED SUCCESSFULY]-----------"
  else echo "------------[CHECK HAS FAILED]-----------------------"
  exit 1
fi
#-----------------------------NODES GENERATION--------------------------------------------------------------------
