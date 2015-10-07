#!/bin/bash
# BE AWARE - this will work only with systemd (ex. Centos 7)
# FILECP : PATH/filename to pod template
# SRV_NAME : username@ip/name of server which should be resolver
# DNS_IP : IP which should be resolved
# DNS_NAME : Name for resolved
# POD_NAME : Test Pod name


function getSystemStatus()
{	
	local lName=$1 # username@ip/name of server
	local lBox=$2  # Pod name
	local lAnswer=$(ssh -q -t $lName kubectl get pods $lBox )

	echo $lAnswer
}

function checkingStatus()
{
	local lAnswer=$1
	# fPrint "checkingStatus: $lAnswer "
	[[ "$lAnswer" == *Error* ]] && echo 1 | echo 0
	
}

testCR()
{	
	local lServ=$1
	local lFile=$2
	fPrint "CPY: $lServ$lFile"
	scp $lFile $lServ:./ >/dev/null 2>&1
	ssh -q -t $lServ kubectl create -f $lFile
}

ANSW=`getSystemStatus $SRV_NAME $POD_NAME`
fPrint "ANSWER: $ANSW"
[[ $(checkingStatus $ANSW) ]] && testCR $SRV_NAME $FILECP || fPrint "Already existed"


# fPrint "THE RES: $ST_CHECK"
