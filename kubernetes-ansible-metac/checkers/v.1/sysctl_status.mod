#!/bin/bash
# BE AWARE - this will work only with systemd (ex. Centos 7)
# ASYSTEMD: Array of services names - which should be in state enabled
# SRV_NAME: login@server_name record for request

getSystemStatus()
{	
	local lServer=$1 	# login@server_name
	local lSystem=$2	# Service name from systemd
	SRV_ANSWER=`ssh -t -q $lServer "sudo systemctl status $lSystem" | head -3 | tail -1 | cut -d':' -f2 | cut -d' ' -f2`
}

for CHK in  ${ASYSTEMD[*]}; do
	getSystemStatus $SRV_NAME $CHK
	fPrint "STATUS $CHK: $SRV_ANSWER"
	if [[ "$SRV_ANSWER" == *inactive* ]]; then 
		ST_CHECK=$((ST_CHECK+1)) 
	fi
done

fPrint "THE RES: $ST_CHECK"
[[ $ST_CHECK -eq 0 ]] && exit 0 || exit 1
