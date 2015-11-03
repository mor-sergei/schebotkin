#!/bin/bash
set -o errexit
set -o nounset
set -o pipefail

debug=0
verbose=0
save=0
dir=$(dirname $(readlink -f ${0}))

function usage
{
    (
        echo "Usage: ${0##*/} --region=region [ --debug --verbose ] [ --mycred=path-to-dev-cred-file ] [ --save ]"
        echo "The script was called from ${dir}."
        echo "Uses region config file for tenant info."
        echo "Developers can set the mycred file to import OS_USERNAME and OS_PASSWORD from. "
        echo
        echo "Credentials file format is bash variables."
        echo "   OS_USERNAME=user"
        echo "   OS_PASSWORD=XXX"
        echo
        echo "--region is required and names the file with definitions for the region/cluster"
        echo "--debug enables cached lookup using previous values after an execution with --save"
        echo "--save enable storing copies of data for debugging. "
        echo "       Since tokens may be stored with --save it is an insecure mode of operation."
        echo "       Use with caution. A secure storage method has not been implemented."
        echo "       In other words don't use save anywhere not private."
    ) > /dev/stderr
    exit 3
}

for arg in ${@}; do
    case ${arg} in
        --region=*)
            region=${arg#*=}
            echo configured for region ${region}
            ;;
        --debug)
            echo enabling debug mode, use local json files for testing.
            debug=1
            ;;
        --verbose)
            echo enabling verbose mode
            verbose=1
            ;;
        --mycred=*)
            mycred=${arg#*=}
            ;;
        --save)
            save=1
            ;;
        --usage|--help|*)
            usage
            ;;
    esac
done

if ! [[ ${region-} ]]; then
    (
        echo
        echo Required option not supplied
        echo
    ) > /dev/stderr
    usage
fi

if (( ! debug )) ; then
    . ${dir}/check-auth.sh
fi

. ${dir}/check-helper.sh

# unit-test-check-compare-value
########################################################################
# Validate critical components
########################################################################
echo "Running tests from scrips in dir ${dir}"

if ! check get-openstack-auth-json ; then
    echo Critical configuration error $?
    exit $?
fi

if ! check get-token ; then
    echo Critical configuration error $?
    exit $?
fi

if (( verbose )); then
    echo # AUTH_TOKEN=${AUTH_TOKEN}
fi

if ! check get-endpoint-url; then
    echo Critical configuration error $?
    exit $?
fi

if (( verbose )); then
    echo # ENDPOINT_URL=${ENDPOINT_URL}
fi

if ! check get-flavors ; then
    echo Critical configuration error $?
    exit $?
fi

if ! check get-images; then
    echo Critical configuration error $?
    exit $?
fi

if ! check get-limits; then
    echo Critical configuration error $?
    exit $?
fi

create-tenant-limits-map
collect-module-json
#create-volume-limits-map
check-quota-instances
check-quota-floating-ips-available
check-quota-cores-available
check-quota-ram-available
check-quota-keypairs
check-quota-security-groups
check-quota-security-group-rules
#check-quota-volume-available
