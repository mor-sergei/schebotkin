#!/bin/bash

# maps used for lookups
declare -A limitsMap
declare -A urlMap
declare -A tokenMap
declare -A volumeLimitsMap

function datetime
{
    date +%Y.%m.%d.%H.%M.%S
}

function check
{
    if [[ -z ${1} ]]; then
        echo "$(datetime) Error in ${0##*/} function check executed without arguments."
        exit 3
    fi
    command=${1}
    printf "$(datetime) Executing step %-63s" ${command}

    ${command}
    rc=${?}
    local verbose=1
    case ${rc} in
        0)
            if (( verbose )); then printf "success rc[${rc}]\n"; fi
            return ${rc}
            ;;
        1)
            if (( verbose )); then printf "warn rc[${rc}]\n"; fi
            return ${rc}
            ;;
        2)
            if (( verbose )); then printf "fail rc[${rc}]\n"; fi
            return ${rc}
            ;;
    esac
}

function touch_and_set_perms
{
    if (( $# < 1 )); then
        echo "$(datetime) Error in ${0##*/} function touch_and_set_perms requires 1 arguments got [$#]."
        exit 3
    fi
    touch ${1}
    chmod 600 ${1}
}

if (( debug || save )) ; then
    TOKENS_FILE=${dir}/tokens
    FLAVORS_FILE=${dir}/flavors
    IMAGES_FILE=${dir}/images
    LIMITS_FILE=${dir}/limits
    VOLUME_LIMITS_FILE=${dir}/cinderv2
fi

if (( save )) ; then

    touch_and_set_perms ${TOKENS_FILE}
    touch_and_set_perms ${FLAVORS_FILE}
    touch_and_set_perms ${IMAGES_FILE}
    touch_and_set_perms ${LIMITS_FILE}
    touch_and_set_perms ${VOLUME_LIMITS_FILE}
fi

function api-call
{
    if [[ -z ${1} ]]; then
        echo "$(datetime) Error in ${0##*/} function api-call executed without arguments. expects URL [api-call URL] "
        exit 3
    fi
    local URL=${1}
    if (( debug )) ; then
        echo curl -s -H "X-Auth-Token:${AUTH_TOKEN}" "${URL}" > /dev/stderr
    fi
    curl -s -H "X-Auth-Token:${AUTH_TOKEN}" "${URL}"
}


function api-call-with-token
{
    if (( ${#} < 2 )); then
        echo "$(datetime) Error in ${0##*/} function api-call-with-token executed without url + token"
        exit 3
    fi
    local URL=${1}
    local TOKEN=${2}
    if (( debug )) ; then
        echo curl -s -H "X-Auth-Token:${TOKEN}" "${URL}" > /dev/stderr
    fi
    curl -s -H "X-Auth-Token:${TOKEN}" "${URL}"
}

function maybe-save
{
    if (( save )); then
        if (( ${#} < 2 )); then
            echo "$(datetime) Error in ${0##*/} function maybe-save json file 2 required arguments got[${#}]"
            exit 3
        fi
        echo "${1}" > "${2}"
    fi
}

function maybe-fail-file-not-found
{
    rc=${?}
    if (( ${#} < 2 )); then
        echo "$(datetime) Error in $(dirname ${0##*/}) function maybe-fail-file-not-found called without 2 arguments, a function and a filename."
        exit 3
    fi

    name=${1}
    file=${2}
    if (( ${rc} )); then
        echo "$(datetime) Error in $(dirname ${0##*/}) function ${name} failed."
        exit 3
    fi
    if ! [[ -e ${file} ]] || ! (( $(stat --format="%s" ${file}) > 1 )); then
        echo "$(datetime) Error in $(dirname ${0##*/}) function ${name} failed file [${file}] not found or too small."
        exit 3
    fi
    return ${rc}
}

function get-openstack-auth-json
{
    if (( debug )) ; then
        export openstack_auth_json=$(cat ${TOKENS_FILE})
        maybe-fail-file-not-found get-openstack-auth-json ${TOKENS_FILE}
    else
        export openstack_auth_json=$(curl -sX POST $OS_AUTH_URL/tokens -H "Content-Type: application/json" \
                                          -d '{"auth": {"tenantName": "'"$OS_TENANT_NAME"'", "passwordCredentials": {"username": "'"$OS_USERNAME"'", "password": "'"$OS_PASSWORD"'"}}}')
        if (( save )) ; then
            maybe-save "${openstack_auth_json}" "${TOKENS_FILE}"
        fi
    fi
}

function maybe-get-openstack-auth-json
{
    if [[ ! ${openstack_auth_json-} || -z ${openstack_auth_json} ]]; then
        get-openstack-auth-json
    fi
}

function get-token {
    export AUTH_TOKEN=$(echo ${openstack_auth_json} | jq --raw-output .access.token.id)
}

# returns an array with a a[0] url and a[1] token
function parse-urls
{
    if (( $# < 1 )); then
        echo "$(datetime) Error in ${0##*/} function parse-url executed without arguments, requires module-name."
        exit 3
    fi
    maybe-get-openstack-auth-json
    local type=${1}
    local expression=".access.serviceCatalog[]|select(.name == \"${type}\").endpoints[].publicURL"
    local url=$(echo ${openstack_auth_json}|jq --raw-output "${expression}")
    echo "${url}"
}

function parse-tokens
{
    echo ${AUTH_TOKEN}
    return 0
    if (( $# < 1 )); then
        echo "$(datetime) Error in ${0##*/} function parse-tokens executed without arguments, requires module-name."
        exit 3
    fi
    maybe-get-openstack-auth-json
    local type=${1}
    local expression=".access.serviceCatalog[]|select(.name == \"${type}\").endpoints[].id"
    local id=$(echo ${openstack_auth_json}|jq --raw-output "${expression}")
    echo "${id}"
}

if (( verbose )); then
    maybe-get-openstack-auth-json
    echo ${openstack_auth_json}|jq --raw-output .access.serviceCatalog[].name
fi

# Create a hash map of the values for later reference. If we got this
# far we successfully authenticated, and pull the json for the limits.
function create-tenant-limits-map
{
    text=$(
        while read line; do echo ${line}; done <<EOF
$(echo ${LIMITS} | jq --raw-output '.limits.absolute|to_entries|.[]|.key,.value'| while read key ; do read value; echo [${key}]="${value}"; done; echo)
EOF
        )
    eval "limitsMap=( ${text} )"
}

function create-url-maps
{
    maybe-get-openstack-auth-json
    local text=$(for module in $(echo ${openstack_auth_json}|jq --raw-output .access.serviceCatalog[].name); do echo "[\"${module}\"]=\"$(parse-urls ${module})\""; done)
    eval "urlMap=(${text})"

    local text=$(for module in $(echo ${openstack_auth_json}|jq --raw-output .access.serviceCatalog[].name); do echo "[\"${module}\"]=\"$(parse-tokens ${module})\""; done)
    eval "tokenMap=(${text})"
    unset text
}

function create-volume-limits-map
{
# {
#   "limits": {
#     "rate": [],
#     "absolute": {
#       "totalSnapshotsUsed": 0,
#       "maxTotalVolumeGigabytes": 1024,
#       "totalGigabytesUsed": 200,
#       "maxTotalSnapshots": 10,
#       "totalVolumesUsed": 3,
#       "maxTotalVolumes": 103
#     }
#   }
# }
    local text=$(
        while read line; do echo ${line}; done <<EOF
$(echo ${VOLUME_LIMITS} | jq --raw-output '.limits.absolute|to_entries|.[]|.key,.value' | while read key ; do \
 read value; echo [${key}]="${value}"; \
done; \
echo)
EOF
          )
    eval "volumeLimitsMap=(${text})"
    if (( verbose )) ; then
        echo
        echo VOLUME LIMITS
        echo
        printf "%-35s %9s\n" "Limit" "Value"
        printf "%-c" -{1..62}; echo
        echo ${VOLUME_LIMITS}|jq --raw-output '.limits.absolute|to_entries|.[]|.key,.value' | \
            while read key; do read value; printf "%-35s %9d\n" "${key}" "${value}"; done
    fi
}


function collect-module-json
{
    create-url-maps
    for module in ${!urlMap[@]}; do
        local pair="$(echo ${urlMap[${module}]})"
        local url=${urlMap[${module}]}
        local id=${AUTH_TOKEN}
        case "${module}" in
            # nova|swift|glance|neutron|cinder)
            #     ;;
            cinderv2)
                if (( debug )); then
                    VOLUME_LIMITS=$(cat ${VOLUME_LIMITS_FILE})
                    maybe-fail-file-not-found collect-module-json ${VOLUME_LIMITS_FILE}
                else
                    VOLUME_LIMITS=$(api-call-with-token ${url}/limits ${id})
                    if (( save )) ; then
                        maybe-save "${VOLUME_LIMITS}" "${VOLUME_LIMITS_FILE}"
                    fi
                fi
                ;;
        esac
    done
}

function get-endpoint-url
{
    export ENDPOINT_URL=$(echo ${openstack_auth_json}|jq --raw-output .access.serviceCatalog[0].endpoints[0].publicURL)
}

function get-storage-url
{
    export STORAGE_URL=$(echo ${openstack_auth_json}|jq --raw-output .access.serviceCatalog[0].endpoints[0].publicURL)
}

function get-flavors
{
    export URL=${ENDPOINT_URL}/flavors
    if (( debug )) ; then
        maybe-fail-file-not-found get-flavors ${FLAVORS_FILE}
        export FLAVORS=$(cat ${FLAVORS_FILE})
    else
        export FLAVORS=$(api-call ${URL})
        if (( save )) ; then
            maybe-save "${FLAVORS}" "${FLAVORS_FILE}"
        fi
    fi

    if (( verbose )); then
        echo FLAVORS
        printf "%c" -{1..30}; echo
        echo ${FLAVORS}|jq --raw-output .flavors[].name |sort
        printf "%-20s %s\n" "Flavor" "Id"
        printf "%-c" -{1..57}; echo
        (
            echo ${FLAVORS}|jq --raw-output '.flavors[]|.name,.id' | \
                while read f id; do if ! [[ ${f-} ]] || ! [[ ${id-} ]]; then continue; fi; printf "%-20s %s\n" "${f}" "${id}"; done
        )

    fi
}

function get-images
{
    export URL=${ENDPOINT_URL}/images
    if (( debug )) ; then
        export IMAGES=$(cat ${IMAGES_FILE})
        maybe-fail-file-not-found get-images ${IMAGES_FILE}
    else
        export IMAGES=$(api-call ${URL})
        if (( save )) ; then
            maybe-save "${IMAGES}" "${IMAGES_FILE}"
        fi
    fi

    if (( verbose )); then
        echo IMAGES
        printf "%c" -{1..50}; echo
        echo ${IMAGES} | jq --raw-output .images[].name |sort | grep -v LICENSE
        echo
        echo Stripping out LICENSE REQUIRED
        echo
        printf "%-35s %s\n" "Images" "Id"
        printf "%-c" -{1..72}; echo
        echo ${IMAGES} |jq --raw-output '.images[]|.name,.id' | \
            while read f; do read id; printf "%-35s %s\n" "${f}" "${id}"; done | grep -v LICENSE
        echo
    fi
}

function get-limits
{
    export URL=${ENDPOINT_URL}/limits
    if (( debug )) ; then
        export LIMITS=$(cat ${LIMITS_FILE})
        maybe-fail-file-not-found get-limits ${LIMITS_FILE}
    else
        export LIMITS=$(api-call ${URL})
        if (( save )) ; then
            maybe-save "${LIMITS}" "${LIMITS_FILE}"
        fi
    fi

    if (( verbose )) ; then
        echo
        echo LIMITS
        echo
        printf "%-35s %9s\n" "Limit" "Value"
        printf "%-c" -{1..62}; echo
        echo ${LIMITS} | jq --raw-output '.limits.absolute|to_entries|.[]|.key,.value' | \
            while read key; do read value; printf "%-35s %9d\n" "${key}" "${value}"; done
    fi
}


function check-compare-value
{
    lv=${1}
    rv=${2}
    compare=${3}
    if (( $# < 3 )); then
        echo "$(datetime) Error in ${0##*/} function check-compare-value requires 3 arguments got [$#]."
        exit 3
    fi
    case ${compare} in
        lt)
            [[ ${lv} -lt ${rv} ]] || return 2
            ;;
        le)
            [[ ${lv} -le ${rv} ]] || return 2
            ;;
        eq)
            [[ ${lv} -eq ${rv} ]] || return 2
            ;;
        ge)
            [[ ${lv} -ge ${rv} ]] || return 2
            ;;
        gt)
            [[ ${lv} -gt ${rv} ]] || return 2
            ;;
        *)
            return 2
            ;;
    esac
}

function check-map-compare
{
    lhs=${1}
    rhs=${2}
    compare=${3}
    if (( %# < 3 )); then
        echo "$(datetime) Error in ${0##*/} function check-map-compare requires 3 arguments got [$#]."
        exit 3
    fi
    lv=${limitsMap[${lhs}]}
    rv=${limitsMap[${rhs}]}
    check-compare-value ${lv} ${rv} ${compare}
}

unit_testing=0
function check-compare
{
    if (( $# < 3 )); then
        echo "$(datetime) Error in ${0##*/} function check-compare requires 3 arguments got [$#]."
        exit 3
    fi
    lhs=${1}
    rhs=${2}
    compare=${3}
    optional=${4}
    printf "$(datetime) Executing step "
    if (( unit_testing )); then
        printf "check-compare with operator[%6d %3s %6d] ${optional} " "${1}" "${compare}" "${2}"
    else
        printf "%-35s %3d available, require %3d " "${optional}" "${2}" "${1}"
    fi
    check-compare-value ${@}
    rc=${?}
    local verbose=1
    case ${rc} in
        0)
            if (( verbose )); then printf "success rc[${rc}]\n"; fi
            return ${rc}
            ;;
        1)
            if (( verbose )); then printf "warn rc[${rc}]\n"; fi
            return ${rc}
            ;;
        2)
            if (( verbose )); then printf "fail rc[${rc}]\n"; fi
            return ${rc}
            ;;
    esac
}

function unit-test-check-compare-value
{
    check-compare 1 2 lt
    check-compare 1 1 lt
    check-compare 2 1 lt

    check-compare 1 2 le
    check-compare 2 2 le
    check-compare 2 1 le

    check-compare 1 2 eq
    check-compare 2 2 eq
    check-compare 2 1 eq

    check-compare 1 2 ge
    check-compare 2 2 ge
    check-compare 2 1 ge

    check-compare 1 2 gt
    check-compare 2 2 gt
    check-compare 2 1 gt
}

function check-quota-instances
{
    required=6
    in_use=${limitsMap[totalInstancesUsed]}
    total=${limitsMap[maxTotalInstances]}
    check-compare "${required}" "$(( total - in_use ))" lt  check-quota-instances
}

function check-quota-floating-ips-available
{
    required=1
    in_use=${limitsMap[totalFloatingIpsUsed]}
    total=${limitsMap[maxTotalFloatingIps]}
    check-compare "${required}" "$(( total - in_use ))" lt  check-quota-floating-ips-available
}

function check-quota-security-groups
{
    required=1
    in_use=${limitsMap[totalSecurityGroupsUsed]}
    total=${limitsMap[maxSecurityGroups]}
    check-compare "${required}" "$(( total - in_use ))" lt  check-quota-security-groups
}

function check-quota-security-group-rules
{
    required=5
    if ! [[ ${limitsMap[totalSecurityGroupRulesUsed]+isset} ]]; then
        echo "--> Warning check-quota-security-group-rules totalSecurityGroupRulesUsed not found."
        limitsMap[totalSecurityGroupRulesUsed]=0
    fi
    in_use=${limitsMap[totalSecurityGroupRulesUsed]}
    total=${limitsMap[maxSecurityGroupRules]}
    check-compare "${required}" "$(( total - in_use ))" lt  check-quota-security-group-rules
}

function check-quota-keypairs
{
    required=1
    echo "--> Warning check-quota-keypairs limits don't report a value in use?"
#    in_use=${limitsMap[]}
    in_use=0
    total=${limitsMap[maxTotalKeypairs]}
    check-compare "${required}" "$(( total - in_use ))" lt  check-quota-key-pairs
}

# Check quota to ensure
# vCPU (32), RAM (48GB), disk (480GB), additional
# 300GB gluster volumes (6 x m1.large) based on current flavors

function check-quota-cores-available
{
    required=16
    in_use=${limitsMap[totalCoresUsed]}
    total=${limitsMap[maxTotalCores]}
    check-compare "${required}" "$(( total - in_use ))" lt  check-quota-cores-available
}

G=$((1024*1024*1024))
M=$((1024*1024))
K=1024

function check-quota-ram-available
{
    required=24 # G
# RAM in MB, so, find G in round numbers / K
    in_use=$(expr ${limitsMap[totalRAMUsed]}/${K}|bc )
    total=$(expr ${limitsMap[maxTotalRAMSize]}/${K}|bc )
    check-compare "${required}" "$(( total - in_use ))" lt  check-quota-ram-available
}

function check-quota-volume-available
{
    required=6
    echo "--> Warning check-quota-volume-available unknown requirement"
    in_use=${volumeLimitsMap[totalVolumesUsed]}
    total=${volumeLimitsMap[maxTotalVolumes]}
    check-compare "${required}" "$(( total - in_use ))" lt  check-quota-volume-available
}
