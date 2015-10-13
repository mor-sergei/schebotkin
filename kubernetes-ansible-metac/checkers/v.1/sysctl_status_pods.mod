#!/bin/bash
# BE AWARE - this will work only with systemd (ex. Centos 7)
# ASYSTEMD: Array of services names - which should be in state enabled
# PODS_NAME: Array of pods login@server_name record for request

ST_CHECK=0 # If ST_CHECK = 0 then every service is up

getSystemStatus()
{	
	local lPod=$1 		# login@server_name
	local lSystem=$2	# Service name from systemd
	POD_ANSWER=`ssh -t -q $lPod "sudo systemctl status $lSystem" | head -3 | tail -1 | cut -d':' -f2 | cut -d' ' -f2`
}

getStatus()
{
local POD=$1
for CHK in  ${ASYSTEMD[*]}; do
	getSystemStatus $POD $CHK
	fPrint "STATUS $CHK: $POD_ANSWER"
	if [[ "$POD_ANSWER" == *inactive* ]]; then 
		ST_CHECK=$((ST_CHECK+1)) 
	fi
done
}

for POD in ${PODS_NAME[*]}; do
	getStatus $POD
done

fPrint "THE RES: $ST_CHECK"
[[ $ST_CHECK -eq 0 ]] && exit 0 || exit 1
