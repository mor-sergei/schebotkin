# Checker module for port status
# Incoming data: OK_CODES, ERR_CODES
# Parameters: URL:PORT
 
getPortStatus()
{	
	local furl=$1
	local fport=$2
	fPrint "GET URL: $furl"
	fPrint "GET PORT:  $fport"
	local lAnswer=`curl -s -o /dev/null -w "%{http_code}" $furl:$fport`
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
	fPrint "CODE ARL: $oarr_len $earr_len"
	

        for (( i=0; i<${oarr_len}; i++ ))
                do
                        #echo OK ${OK_CODES[$i]}
                        if [ $answer -eq ${OK_CODES[$i]} ]; then ((ok_code++)); fi
                done

        for (( i=0; i<${earr_len}; i++ ))
                do
                        #echo ERR ${ERR_CODES[$i]}
                        if [ $answer -eq ${ERR_CODES[$i]} ]; then ((err_code++)); fi
                done

        if [ $ok_code -eq 1 ]; then return 0
        elif [ $err_code -eq 1 ]; then return 1
        else return 3
        fi
}

getPortStatus $URL $PORT
checkUAnswer $ANSW 
exit $?
