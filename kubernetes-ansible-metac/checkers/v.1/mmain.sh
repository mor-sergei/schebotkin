#!/bin/bash  
# Developed by Sergii Chebotkin 28.09.2015 
# Mail: sergii.chebotkin@mail.ru

CONF="./default.cfg"
MODL="./default.mod"

DEBUG=3

fPrint() 
{
 case $DEBUG in
  1);;
  2);;
  3) ((fPrt++)) ; echo "[ $fPrt ] :  ${@}" ;;
 esac
}

getConfig()
{
	fPrint "Configure from: ${@}"
	source ${@}
}

function modStarter()
{
	local fName=${@}
	fPrint "modStarter: $fName"

	if [ -n $fName ]  
		then 
			fPrint "Module attached: $MODULES$fName" 
			source $MODULES$fName
		else 
			fPrint "No any module has found" 
			exit 3
	fi
}

# MAIN

if [ -z ${1} ] 
 then
  echo "ERROR: NO PARAMS HAS FOUND"
  exit 1
 else
  echo "APPLICATION STARTED TO GET CONFIGS"
fi

for args in ${@}
 do
  case $args in
	-q) DEBUG=1; shift ;;
       --*) ((step++));ARG[$step]="${args#*--}"; fPrint "GOT PARAM: $args";shift ;;
         *) fPrint "WRONG:${args}"; break ;;
  esac
 done

for i in ${ARG[@]}
 do
  fPrint "ARGUMENT: ./$i.mod"
  [[ -e "./$i.mod" ]] && fPrint "SERVICE: EXIST" || fPrint "SERVICE: WRONG"
  [[ -e "./$i.cfg" ]] && fPrint "CONFIG: EXIST" || fPrint "CONFIG: WRONG"
 done

exit 0
#getConfig ${CONF}
#modStarter $MOD_INS
