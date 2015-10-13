#!/bin/bash
# BE AWARE - this will work only with systemd (ex. Centos 7)
# FILECP : PATH/filename to pod template
# SRV_NAME : username@ip/name of server which should be resolver
# DNS_IP : IP which should be resolved
# DNS_NAME : Name for resolved
# POD_NAME : Test Pod name


ip2dec () 
{
    local a b c d ip=$@
    IFS=. read -r a b c d <<< "$ip"
    printf '%d\n' "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))"
}

function getSystemStatus()
{	
	local lName=$1 # username@ip/name of server
	local lBox=$2  # Pod name
	local lAnswer=$(ssh -q -t $lName kubectl get pods $lBox) 

	echo $lAnswer
}
 
function checkingStatus()
{
	local lAnswer=$1
	# fPrint "checkingStatus: $lAnswer "
	[[ "$lAnswer" == *Error* ]] && echo true || echo false
	
}

function getDnsStatus()
{
	local lServ=$1 
	local lPodName=$2
	local lDnsName=$3
	local lDnsIp=$4
	local lAnswer=`ssh -q -t $lServ kubectl exec $lPodName -- nslookup $lDnsName | tail -1 | cut -d':' -f2 | tr '\r' '\n'`
	ip_one=`ip2dec $lAnswer`
	ip_two=`ip2dec $lDnsIp`
	[[ $ip_one -eq $ip_two ]] && echo true || echo false
}

testCR()
{	
	local lServ=$1
	local lFile=$2
	fPrint "CPY: $lServ$lFile"
	scp $lFile $lServ:./ >/dev/null 2>&1
	ssh -q -t $lServ kubectl create -f $lFile >/dev/null 2>&1
}

ANSW=`getSystemStatus $SRV_NAME $POD_NAME`
#fPrint "ANSWER: $ANSW"
[[ $(checkingStatus $ANSW) = true ]] && testCR $SRV_NAME $FILECP || fPrint "Already existed"
sleep 6 
ST_CHECK=`getDnsStatus $SRV_NAME $POD_NAME $DNS_NAME $DNS_IP`

fPrint "MOD STATUS ON EXIT: $ST_CHECK"
[[ $ST_CHECK -ne 0 ]] && exit 1 || fPrint "CHECK PASSED"
