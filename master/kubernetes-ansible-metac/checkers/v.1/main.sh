#!/usr/bin/env bash
# Developed by Sergii Chebotkin 28.09.2015 
# Mail: sergii.chebotkin@mail.ru

cfgDir=`pwd`"/"
cfgFile="default.cfg"
CONFIGURATION=$cfgDir$cfgFile

OK_CODES=(200 201 204 301)
ERR_CODES=""

function getConfig()
{
	echo "Configure from: "${@}
	source ${@}
}

function getParam() 
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

function getPortStatus()
{	
	local url=$1
	local port=$2
	echo `curl -s -o /dev/null -w "%{http_code}" $url:$port`
	return
}

function checkUAnswer
{
	local answer=$1
	local arr_len=${#OK_CODES[@]}
	local diff=0
	for (( i=0; i<${arr_len}; i++ ));
		do
  			#echo ${OK_CODES[$i]}
  			if [ $answer -eq ${OK_CODES[$i]} ]; then ((diff++)); fi
		done
	if [ $diff -ne 0 ]
	 then return 1
		else return 0 
	fi
}

getParam ${@}
getConfig ${CONFIGURATION}
checkUAnswer $(getPortStatus $URL $PORT)
echo $?

exit 0 