#!/bin/bash

# Checker module for port status
# Incoming data: OK_CODES, ERR_CODES
# Parameters: URL

getPortStatus()
{	

	local furl=$1
	fPrint "GET URL: $furl"
	local lAnswer=`curl -I $furl 2>/dev/null | head -n 1 | cut -d$' ' -f2`
	fPrint "SRV ANSW: $lAnswer"
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

getPortStatus $URL
checkUAnswer $ANSW 
fPrint "THE RES: $?"
exit $?
