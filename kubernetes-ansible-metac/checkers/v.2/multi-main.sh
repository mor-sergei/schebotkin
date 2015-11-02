#!/bin/bash
# Developed by Sergii Chebotkin 28.09.2015
# Mail: sergii.chebotkin@mail.ru

CONF="./default.cfg"
MODL="./default.mod"
#ST_CHECK=0

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
        fPrint "CFG PRC GET PARAM: ${@}"
        source ${@}
}

function modStarter()
{
        local fName=${@}
        fPrint "modStarter: $fName"

        if [ -n $fName ]
                then
                        fPrint "Module attached: $fName"
                        source $fName
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

getParam()
{
for args in ${@}
 do
  case $args in
        -q) DEBUG=1; shift ;;
        -p=* | --path=*) MODULES="${args#*=}"; fPrint "GOT PARAM: $args";shift ;;
       --*) ((step++));ARG[$step]="${args#*--}"; fPrint "GOT PARAM: $args";shift ;;
         *) fPrint "WRONG:${args}"; break ;;
  esac
 done
}

main()
{
for i in ${ARG[@]}
 do
  fPrint "ARGUMENT: $MODULES/$i.mod"
  if [ -e ${MODULES}/${i}.mod ]; then MOD_INS="$MODULES/$i.mod"; fPrint "SERVICE: EXIST $MOD_INS"
   else fPrint "ERROR MOD: ${MODULES}/${i}.mod IS WRONG, EXIT"; exit 1;
  fi
  if [ -e ${MODULES}/${i}.cfg ]; then CONF="$MODULES/$i.cfg"; fPrint "CONFIG: EXIST $CONF"
   else fPrint "ERROR CFG: ${MODULES}/${i}.cfg IS WRONG, EXIT"; exit 1
  fi

getConfig ${CONF}
modStarter ${MOD_INS}
done
}

getParam ${@}
main
