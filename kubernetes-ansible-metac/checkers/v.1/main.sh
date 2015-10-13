#!/bin/bash  
# Developed by Sergii Chebotkin 28.09.2015 
# Mail: sergii.chebotkin@mail.ru

cfgDir=`pwd`"/"
cfgFile="default.cfg"
CONFIGURATION=$cfgDir$cfgFile
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

getParam() 
{
	for args in ${@} 
		do 
			case $args in
				-c=* | --configure=*)
				CONFIGURATION="${args#*=}.cfg"
				((step++))
				shift
    			;;
				-m=* | --module=*)
				MOD_INS="${args#*=}.mod"
				shift
			;;
			
				-mc=*)
				CONFIGURATION="${args#*=}.cfg"
				MOD_INS="${args#*=}.mod"
				fPrint "CFG: "$CONFIGURATION
				fPrint "MOD: "$MOD_INS
				shift
			;;
			
				--*)
				CONFIGURATION="${args#*--}.cfg"
                                MOD_INS="${args#*--}.mod"
                                fPrint "CFG: "$CONFIGURATION
                                fPrint "CFG: "$CONFIGURATION
				shift

			;;
    				*)
				echo "[WRONG PARAMITER]" 
				break
				exit 1
				
			;;
			esac
		done
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

function chkMod()
{

	local lmod="$1.mod"
	[[ -e $lmod ]] && echo TRUE || echo FALSE

}

# Main section

getParam ${@}
[[ $? -eq 1 ]] && exit 1
getConfig ${CONFIGURATION}
modStarter $MOD_INS
