#!/bin/bash

# Checker module for port status
# Incoming data: OK_CODES, ERR_CODES
# Parameters: URL

getPortStatus()
{	

	local furl=$1 
	local ffunct=$2

	fPrint "GET URL: $furl"
	fPrint "GET Function: $ffunct"

	local lRequest="$furl$ffunct"
	fPrint "Request: "$lRequest
	#curl -k -I -H "Authorization: Bearer $TOKEN" $lRequest 2>/dev/null | head -n 1 | cut -d$' ' -f2
	local lAnswer=`curl -k -I -l -H "Authorization: Bearer $TOKEN" $lRequest 2>/dev/null | head -n 1 | cut -d$' ' -f2`
	ANSW=$lAnswer
}

function checkUAnswer()
{

        local param=$1
	local answer=$((param+0)) 
        local oarr_len=${#OK_CODES[@]}
        local earr_len=${#ERR_CODES[@]}
        local ok_code=0
        local err_code=0
	fPrint "LEN O E S ARR: $oarr_len $earr_len"
	fPrint "CHK STS: $answer"
        for OCD in ${OK_CODES[*]}; do [[ $answer -eq ${OCD} ]] && ((ok_code++)); done
	for OCD in ${ERR_CODES[*]}; do [[ $answer -eq ${OCD} ]] && ((err_code++)); done

        if [ $ok_code -eq 1 ]; then return 0
        elif [ $err_code -eq 1 ]; then return 1
        else return 3
        fi
}

for CHK in ${SERVICES[*]}; do 
	getPortStatus $URL $CHK
	checkUAnswer $ANSW
	RES=$?
	ST_CHECK=$((ST_CHECK+RES))
done

fPrint "MOD STATUS ON EXIT: $ST_CHECK"
[[ $ST_CHECK -ne 0 ]] && exit 1 || fPrint "CHECK PASSED"
