#!/usr/bin/env bash
# Developed by Sergii Chebotkin 28.09.2015 
# Mail: sergii.chebotkin@mail.ru

cfgDir=`pwd`"/"
cfgFile="default.cfg"
CONFIGURATION=$cfgDir$cfgFile

getConfig()
{
	echo "Configure from: "${@}
	source ${@}
}

getParam() 
{
	for args in ${@} 
		do 
			case $args in
				-c=* | --configure=*)
					CONFIGURATION="${args#*=}"
					#echo $CONFIGURATION
					((step++))
					shift
    			;;
    			*) 
					DEFAULT=true
				;;
			esac
		done
	if [ $DEFAULT ]; then  ((step++));echo "Your parameter $step are wrong"; fi
}

getPortStatus()
{	
	local url=$1
	local port=$2
	echo `curl -s -o /dev/null -w "%{http_code}" $url:$port`
}

function checkUAnswer()
{
	local answer=$1; echo "Server answer: $answer"
	local oarr_len=${#OK_CODES[@]}
	local earr_len=${#OK_CODES[@]}
	local ok_code=0
	local err_code=0

	for (( i=0; i<${oarr_len}; i++ ));
		do
  			#echo OK ${OK_CODES[$i]}
  			if [ $answer -eq ${OK_CODES[$i]} ]; then ((ok_code++)); fi
		done

        for (( i=0; i<${earr_len}; i++ ));
                do
                        #echo ERR ${ERR_CODES[$i]}
                        if [ $answer -eq ${ERR_CODES[$i]} ]; then ((err_code++)); fi
                done
	
	if [ $ok_code -eq 1 ]; then return 0
	elif [ $err_code -eq 1 ]; then return 1
	else return 3
	fi
}

getParam ${@}
getConfig ${CONFIGURATION}
checkUAnswer $(getPortStatus $URL $PORT)
echo $?

exit 0 
