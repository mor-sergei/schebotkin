#!/bin/bash

# Checker module for port status
# Incoming data: OK_CODES, ERR_CODES
# Parameters: URL:PORT

TOKEN="jRkO9ho6jv0VuA5ORmghLq8bWbJ1xrx4" \
SRV_API="10.1.12.6" \
API_STR="/api/v1/proxy/namespaces/kube-system/services/kibana-logging" \
REQW="https://$SRV_API:443$API_STR" \
curl -k -I -H "Authorization: Bearer $TOKEN" $REQW 2>/dev/null | head -n 1 | cut -d$' ' -f2
 
getPortStatus()
{	

	local furl=$1
	local fport=$2
	fPrint "GET URL: $furl"
	fPrint "GET PORT:  $fport"
	local lAnswer=`curl -I -H \"Authorization: Bearer $TOKEN\" $ADDR `
	fPrint "SRV ANSW: $lAnswer"
	ANSW=$lAnswer
}

function checkUAnswer()
{

        local param=$1
	local answer=$((param+0)) 
        local oarr_len=${#OK_CODES[@]}
        local earr_len=${#ERR_CODES[@]}
	local sarr_len=${#SERVICES[@]}
        local ok_code=0
        local err_code=0
	fPrint "LEN O E S ARR: $oarr_len $earr_len $sarr_len"
	fPrint "CHK STS: $answer"
        for OCD in ${OK_CODES[*]}; do [[ $answer -eq ${OSD} ]] && ((ok_code++)); done
	for OCD in ${ERR_CODES[*]}; do [[ $answer -eq ${OSD} ]] && ((err_code++)); done

        if [ $ok_code -eq 1 ]; then return 0
        elif [ $err_code -eq 1 ]; then return 1
        else return 3
        fi
}

ANSW="301"
# getPortStatus $URL $PORT
checkUAnswer $ANSW 
exit $?
