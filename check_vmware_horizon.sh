#!/bin/bash
#
# Monitor plugin for checking vmware Horizon Connection Server via API
#
# Author:
#   Felix Longardt <monitoring@longardt.com>
#
# Version history:
# 2022-02-10 Felix Longardt <monitoring@longardt.com>
# Release: 0.0.1
#   Initial release
# 2022-02-27 Felix Longardt <monitoring@longardt.com>
# Release: 0.1.0
#   Add a lot of functionality, verbose output etc..

## VARIABLES
PROGNAME="${0##*/}"
PROGPATH="${0%/*}"
REVISION="1.0.0"
JQ="$(which jq)"
CURL="$(which curl)"
AWK="$(which awk)"
DATE="$(which date)"
#SED="$(which sed)"

exit_unknown() {
        echo "Unknown parameter: ${1}"
        print_usage
        exit 4 
}

## FUNCTIONS
print_usage() {
        echo "Usage: ${PROGNAME} [-h] [-V] -H <hostname> [-U <username>] [-P <password>] [-D <domain>] [-opts] [-w <warning>] [-c <critical>] [-v]"
}

print_help() {
        print_revision "${PROGNAME}" "${REVISION}"
        echo ""
        print_usage
cat << EOM

 This plugin checks several statistics of a vmware Horizon Connection Server via API.

Options:
 -h, --help
    Print detailed help screen
 -V, --version
    Print version information
 -i, --input <integer>
    Set input value to INTEGER percent
 -H, --hostname <hostname>
    Set ipadress or hostname for destination
 -U, --username <username>
    Set Username for Login
 -P, --password <password>
    Set Password for Login
 -D, --domain <domain>
    Set Domain for Login
 -eCS---enable-connectionserver
    Enable Connection Server check
 -eGW--enable-gateway
    Enable Gateway check
 -eVC--enable-vcenter
    Enable vCenter check
 -eDB--enable-db
    Enable Event DB check
 -eAD--enable-ad
    Enable AD-Domain check
 -eRDS--enable-rds
    Enable RDS Server check
 -eFA--enable-farms
    Enable RDS Farms check
 -eSA--enable-saml
    Enable RDS Farms check
 -eTS--enable-truesso
    Enable True SSO check
 -ePO--enable-pod
    Enable POD check
 -A|--enable-all
    Enable all available SNMP checks.
 -w, --warning <integer>
    Set WARNING status if more than INTEGER is used,
    if --enable-all ist set, defaults are used
 -c, --critical <integer>
    Set CRITICAL status if more than INTEGER is used,
    if --enable-all ist set, defaults are used
 -s, --silent
    Silent all extra output
 -v, --verbose
    Print extra Information

Example: ${PROGNAME} -H <hostname> -P <PASSWORD> -D <DOMAIN> -A

EOM
}

## BEGIN
# Grab command line arguments
while [[ -n "${1}" ]]; do
        case "${1}" in
        -h|--help)
                print_help
                exit ${STATE_OK}
                ;;
        -V|--version)
                print_revision "${PROGNAME}" "${REVISION}"
                exit ${STATE_OK}
                ;;
        -H|--host)
                shift
                api_host="${1}"
                ;;
        -U|--username)
                shift
                api_username="${1}"
                ;;
        -P|--password)
                shift
                api_password="${1}"
                ;;
        -D|--domain)
                shift
                api_domain="${1}"
                ;;
        -eCS|---enable-connectionserver)
                enable_hvcs=1
                ;;
        -eGW|--enable-gateway)
                enable_gw=1
                ;;
        -eDB|--enable-db)
                enable_db=1
                ;;
        -eAD|--enable-ad)
                enable_ad=1
                ;;
        -eVC|--enable-vcenter)
                enable_vc=1
                ;;
        -eFA|--enable-farms)
                enable_farms=1
                ;;
        -eSA|--enable-saml)
                enable_saml=1
                ;;
        -ePO|--enable-pod)
                enable_pod=1
                ;;
        -eTS|--enable-truesso)
                enable_tsso=1
                ;;
        -eRDS|--enable-rds)
                enable_rds=1
                ;;
        -A|--enable-all)
                enable_all=1
                ;;
        -w|--warning)
                shift
                warning="${1//%}"
                [[ "${warning}" =~ [0-9].* ]] || exit_unknown "${1}"
                ;;
        -c|--critical)
                shift
                critical="${1//%}"
                [[ "${critical}" =~ [0-9].* ]] || exit_unknown "${1}"
                ;;
        -s|--silent)
                silent=1
                ;;
        -v|--verbose)
                verbose=1
                ;;
        -d|--debug)
                debug=1
                ;;
        *)
                exit_unknown "${1}"
                ;;
        esac
        shift
done

# Check mandatory parameters
[[ -z "${api_host}" ]] && exit_unknown "Host is required!"
[[ -z "${api_username}" ]] && exit_unknown "Username is required!"
[[ -z "${api_password}" ]] && exit_unknown "Password is required!"
[[ -z "${api_domain}" ]] && exit_unknown "Domain is required!"
[[ -z "${CURL}" ]] && exit_unknown "curl is requied! - please install it"
[[ -z "${JQ}" ]] && exit_unknown "jq is requied! - please install it"
[[ -z "${AWK}" ]] && exit_unknown "awk is requied! - please install it"

# Set defaults
[[ 
-z "${enable_gw}" && 
-z "${enable_hvcs}" && 
-z "${enable_db}" && 
-z "${enable_ad}" && 
-z "${enable_farms}" && 
-z "${enable_saml}" && 
-z "${enable_pod}" && 
-z "${enable_tsso}" && 
-z "${enable_rds}" && 
-z "${enable_all}" && 
-z "${enable_gw}" 
]] && enable_gw=1 && enable_hvcs=1

## TODO
cs_total_sessions_warn=50
cs_total_sessions_crit=150
cs_current_sessions_warn=50
cs_current_sessions_crit=150
gw_current_sessions_warn=50
gw_current_sessions_crit=150
cs_cert_warn=14
cs_cert_crit=7
today=${EPOCHSECONDS}
# Some Basic API settings
#CURL_OPTS_POST="-k --tcp-fastopen -X POST "

CURL_OPTS_POST="-k -X POST --silent"
CURL_OPTS_GET="-k -X GET --silent"
CURL_OPTS_JSON="Content-Type: application/json"
api_url="https://${api_host}"
horizon_perf=""
horizon_check=""
horizon_output=""
#
api_cmd_post="${CURL} ${CURL_OPTS_POST} ${api_url}"
api_cmd_get="${CURL} ${CURL_OPTS_GET} ${api_url}"

declare -a api_connect
api_connect=(`${api_cmd_post}/rest/login -H "${CURL_OPTS_JSON}" -d '{
    "username": "'"${api_username}"'",
    "password": "'"${api_password}"'",
    "domain": "'"${api_domain}"'"
}' | "${JQ}" --unbuffered -r '.access_token,.refresh_token' | "${AWK}" 1 ORS=' ' `)
#}' | "${SED}" -E 's/.*"access_token":"?([^,"]*)"?.*/\1/'`)
CURL_OPTS_AUTH="Authorization: Bearer ${api_connect[0]}"
# 0 = access token, 1 = refresh token

if [[ -z "${api_connect[0]}" ]]; then
exit_unknown "Problem while gathering API Token"
fi
if [[ -n "$debug" ]];then
	echo "Debugging mode ON." 1>&2 
	set -x
fi

# Yep, dirty and lost in coding, TBD: Cleanup
## Gather Some facts
# Connection Server Api Call
if [[ -n "$enable_hvcs" || -n "$enable_all" ]]; then
	cs_buffer=`${api_cmd_get}/rest/monitor/connection-servers -H "${CURL_OPTS_AUTH}" -H "${CURL_OPTS_JSON}"`
	if [[ "${cs_buffer}" != "[]" ]]; then
	# Lets declare some doomsday arrays for the Connenction Server Infos :P
	declare -a cs_status 
	declare -a cs_tunnel 
	declare -a cs_name 
	declare -a cs_id 
	declare -a cs_certv 
	declare -a cs_certvf
	declare -a cs_certvt 
	declare -a cs_certd 
	declare -a cs_build 
	declare -a cs_version 
	declare -a cs_connc 
	declare -a cs_csreps
	declare -a cs_csrepstate 
	declare -a cs_svcsgw 
	declare -a cs_svcpcoip 
	declare -a cs_svcblast 
	declare -a cs_sessc 
	declare -a cs_sessp
	cs_status=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].status' | "${AWK}" 1 ORS=' '` )
	cs_tunnel=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].tunnel_connection_count' | "${AWK}" 1 ORS=' ' ` )
	cs_name=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].name' | "${AWK}" 1 ORS=' '`)
	cs_id=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].id' | "${AWK}" 1 ORS=' ' `)
	cs_certv=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].certificate.valid' | "${AWK}" 1 ORS=' ' `)
	cs_certvf=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].certificate.valid_from' | "${AWK}" 1 ORS=' ' `)
	cs_certvt=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].certificate.valid_to' | "${AWK}" 1 ORS=' ' `)
	cs_certd=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].default_certificate' | "${AWK}" 1 ORS=' ' `)
	cs_build=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].details.build' | "${AWK}" 1 ORS=' ' `)
	cs_version=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].details.version' | "${AWK}" 1 ORS=' ' `)
	cs_connc=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].connection_count' | "${AWK}" 1 ORS=' ' `)
	cs_csreps=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].cs_replications | .[].server_name? ' | "${AWK}" 1 ORS=' ' `)
	cs_csrepstate=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].cs_replications | .[].status? '| "${AWK}" 1 ORS=' ' `)
	cs_sessc=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].session_protocol_data | .[].session_count? ' | "${AWK}" 1 ORS=' ' `)
	cs_sessp=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].session_protocol_data | .[].session_protocol? '| "${AWK}" 1 ORS=' ' `)
	cs_svcsgw=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].services | map(select(.service_name == "SECURITY_GATEWAY_COMPONENT")) | .[].status?' | "${AWK}" 1 ORS=' ' `)
	cs_svcblast=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r  '.[].services | map(select(.service_name == "BLAST_SECURE_GATEWAY")) | .[].status?' | "${AWK}" 1 ORS=' ' `)
	cs_svcpcoip=( `echo "${cs_buffer}" | "${JQ}" --unbuffered -r '.[].services | map(select(.service_name == "PCOIP_SECURE_GATEWAY")) | .[].status?' | "${AWK}" 1 ORS=' ' `)
	for count in "${!cs_id[@]}"
		do
		cscertcreate=$(${DATE} -d@"${cs_certvf[count]::-3}")
		cscertexpire=$(${DATE} -d@"${cs_certvt[count]::-3}")
		cscertexpirew=`${DATE} -d "$(${DATE} --date "${cscertexpire} -${cs_cert_warn} days")" '+%s'`
		cscertexpirec=`${DATE} -d "$(${DATE} --date "${cscertexpire} -${cs_cert_crit} days")" '+%s'`
		if [[ -n "${verbose}" ]]; then 
		horizon_output+="Status of Connection Server: ${cs_name[count]}\n---------------------------------------\n"
		fi
		if [[ "${cs_status[count]}" == "UNKNOWN" ]]; then
			horizon_output+="[UNKNOWN] - Status of ${cs_name[count]} (Version: ${cs_version[count]} Build: ${cs_build[count]}) is ${cs_status[count]}\n"
			horizon_problem_output+="[UNKNOWN] - Connection Server - Status of ${cs_name[count]} (Version: ${cs_version[count]} Build: ${cs_build[count]}) is ${cs_status[count]}\n"
		elif [[ "${cs_status[count]}" == "ERROR" ]]; then
			horizon_output+="[CRITICAL] - Status of ${cs_name[count]} (Version: ${cs_version[count]} Build: ${cs_build[count]}) is ${cs_status[count]}\n"
			horizon_problem_output+="[CRITICAL] - Connection Server - Status of ${cs_name[count]} (Version: ${cs_version[count]} Build: ${cs_build[count]}) is ${cs_status[count]}\n"
		elif [[ "${cs_status[count]}" == "NOT_RESPONDING" ]]; then
			horizon_output+="[WARNING] - Status of ${cs_name[count]} (Version: ${cs_version[count]} Build: ${cs_build[count]}) is ${cs_status[count]}\n"
			horizon_problem_output+="[WARNING] - Connection Server - Status of ${cs_name[count]} (Version: ${cs_version[count]} Build: ${cs_build[count]}) is ${cs_status[count]}\n"
		elif [[ "${cs_status[count]}" == "OK" ]]; then
			horizon_output+="[OK] - Status of ${cs_name[count]} (Version: ${cs_version[count]} Build: ${cs_build[count]}) is ${cs_status[count]}\n"
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - Connection Server - an unexpected error occured\n"
		fi
		if [[ "${cs_svcsgw[count]}" == "UNKNOWN" ]]; then
			horizon_output+="[UNKNOWN] - Status of Security Gateway ${cs_svcsgw[count]}\n"
			horizon_problem_output+="[UNKNOWN] - Connection Server - Status of Security Gateway ${cs_svcsgw[count]}\n"
		elif [[ "${cs_svcsgw[count]}" == "DOWN" ]]; then
			horizon_output+="[CRITICAL] - Status of Security Gateway ${cs_svcsgw[count]}\n"
			horizon_problem_output+="[CRITICAL] - Connection Server - Status of Security Gateway ${cs_svcsgw[count]}\n"
		elif [[ "${cs_svcsgw[count]}" == "UP" ]]; then
			horizon_output+="[OK] - Status of Security Gateway ${cs_svcsgw[count]}\n"
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured"
			horizon_problem_output+="[UNKNOWN] - Connection Server - an unexpected error occured"
		fi
		if [[ "${cs_svcpcoip[count]}" == "UNKNOWN" ]]; then
			horizon_output+="[UNKNOWN] - PCoIP Gateway ${cs_svcpcoip[count]}\n"
			horizon_problem_output+="[UNKNOWN] - Connection Server - PCoIP Gateway ${cs_svcpcoip[count]}\n"
		elif [[ "${cs_svcpcoip[count]}" == "DOWN" ]]; then
			horizon_output+="[CRITICAL] - PCoIP Gateway ${cs_svcpcoip[count]}\n"
			horizon_problem_output+="[CRITICAL] - Connection Server - PCoIP Gateway ${cs_svcpcoip[count]}\n"
		elif [[ "${cs_svcpcoip[count]}" == "UP" ]]; then
			horizon_output+="[OK] - PCoIP Gateway ${cs_svcpcoip[count]}\n"
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - Connection Server - an unexpected error occured\n"
		fi
		if [[ "${cs_svcblast[count]}" == "UNKNOWN" ]]; then
			horizon_output+="[UNKNOWN] - BLAST Gateway ${cs_svcblast[count]}\n"
			horizon_problem_output+="[UNKNOWN] - Connection Server - BLAST Gateway ${cs_svcblast[count]}\n"
		elif [[ "${cs_svcblast[count]}" == "DOWN" ]]; then
			horizon_output+="[CRITICAL] - BLAST Gateway ${cs_svcblast[count]}\n"
			horizon_problem_output+="[CRITICAL] - Connection Server - BLAST Gateway ${cs_svcblast[count]}\n"
		elif [[ "${cs_svcblast[count]}" == "UP" ]]; then
			horizon_output+="[OK] - BLAST Gateway ${cs_svcblast[count]}\n"
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - Connection Server - an unexpected error occured\n"
		fi
		if [[ "${cs_csrepstate[count]}" == "ERROR" ]]; then
			horizon_output+="[CRITICAL] - Replication to peer ${cs_csreps[count]} returned ${cs_csrepstate[count]}\n"
			horizon_problem_output+="[CRITICAL] - Connection Server - Replication to peer ${cs_csreps[count]} returned ${cs_csrepstate[count]}\n"
		elif [[ "${cs_csrepstate[count]}" == "OK" ]]; then
			horizon_output+="[OK] - Replication to peer ${cs_csreps[count]} is ${cs_csrepstate[count]}\n"
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - Connection Server - an unexpected error occured\n"
		fi
		if [[ ! "${cs_certv[count]}" == "true" ]]; then
			horizon_output+="[CRITICAL] - Certificate from ${cs_name[count]} is not valid\n"
			horizon_problem_output+="[CRITICAL] - Connection Server - Certificate from ${cs_name[count]} is not valid\n"
		elif [[ "${cs_certv[count]}" == "true" ]]; then
			horizon_output+="[OK] - Certificate from ${cs_name[count]} is valid\n"
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - Connection Server - an unexpected error occured\n"
		fi
		if [[ "${cs_certd[count]}" == "true" ]]; then
			horizon_output+="[WARNING] - Default Certificate Certificate is in use and should be changed!\n"
			horizon_problem_output+="[WARNING] - Connection Server - Default Certificate Certificate is in use and should be changed!\n"
		elif [[ ! "${cs_certd[count]}" == "true" ]]; then
			horizon_output+="[OK] - Default Cetificate is not in use\n"
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - Connection Server - an unexpected error occured\n"
		fi
		if [[ "${today}" -ge "${cscertexpirec}" ]]; then
			horizon_output+="[CRITICAL] - Certificate expires on ${cscertexpire}\n"
			horizon_problem_output+="[CRITICAL] - Connection Server - Certificate expires on ${cscertexpire}\n"
		elif [[  "${today}" -ge "${cscertexpirec}" ]]; then
			horizon_output+="[WARNING] - Certificate expires on ${cscertexpire}\n"
			horizon_problem_output+="[WARNING] - Connection Server - Certificate expires on ${cscertexpire}\n"
		elif [[ "${today}" -lt "${cscertexpirec}" && "${today}" -lt "${cscertexpirew}" ]]; then
			horizon_output+="[OK] - Certificate is valid and will be expire on "${cscertexpire}"\n"
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - Connection Server - an unexpected error occured\n"
		fi
		if [[ "${cs_connc[count]}" -gt "${cs_current_sessions_crit}" || "${cs_sessc[count]}" -gt "${cs_total_sessions_crit}" ]]; then
			horizon_output+="[CRITICAL] - Session Count Total: ${cs_sessc[count]}, Current Connections: ${cs_connc[count]}, Tunnel Connections: ${cs_tunnel[count]}, Session Protocol: ${cs_sessp[count]}\n"
			horizon_problem_output+="[CRITICAL] - Connection Server - Session Count Total: ${cs_sessc[count]}, Current Connections: ${cs_connc[count]}, Tunnel Connections: ${cs_tunnel[count]}, Session Protocol: ${cs_sessp[count]}\n"
		elif [[ "${cs_connc[count]}" -ge "${cs_current_sessions_warn}" || "${cs_sessc[count]}" -ge "${cs_total_sessions_warn}" ]]; then
			horizon_output+="[WARNING] - Session Count Total: ${cs_sessc[count]}, Current Connections: ${cs_connc[count]}, Tunnel Connections: ${cs_tunnel[count]}, Session Protocol: ${cs_sessp[count]}\n"
			horizon_problem_output+="[WARNING] - Connection Server - Session Count Total: ${cs_sessc[count]}, Current Connections: ${cs_connc[count]}, Tunnel Connections: ${cs_tunnel[count]}, Session Protocol: ${cs_sessp[count]}\n"
		elif [[ "${cs_connc[count]}" -lt "${cs_current_sessions_warn}" || "${cs_sessc[count]}" -lt "${cs_total_sessions_warn}" ]]; then
			horizon_output+="[OK] - Session Count Total: ${cs_sessc[count]}, Current Connections: ${cs_connc[count]}, Tunnel Connections: ${cs_tunnel[count]}, Session Protocol: ${cs_sessp[count]}\n"
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - Connection Server - an unexpected error occured\n"
		fi
		if [[ -n "${verbose}" ]]; then 
		horizon_output+="---------------------------------------\n\n"
		fi
		if [[ ! "${horizon_perf}" =~ "Session_count_total" ]]; then
        	horizon_perf+=" Session_count_total=${cs_sessc[count]};${cs_total_sessions_warn};${cs_total_sessions_crit}"
		fi
        	horizon_perf+=" ${cs_name[count]}_session_count_tunnel=${cs_tunnel[count]};0;0"
        	horizon_perf+=" ${cs_name[count]}_session_count_current_${cs_sessp[count]}=${cs_connc[count]};${cs_current_sessions_warn};${cs_current_sessions_crit}"
	done
	else
	cs_notset="No Connection Server Configured"
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Status of Connection Servers:\n---------------------------------------\n[OK] - ${cs_notset}\n"
  		horizon_output+="---------------------------------------\n\n"
		fi
	fi
fi
	if [[ -z ${cs_notset} ]]; then
	unset cs_status cs_tunnel cs_name cs_id cs_certv cs_certvf cs_certvt cs_certd cs_build cs_version cs_connc cs_csreps cs_csrepstate cs_svcsgw cs_svcpcoip cs_svcblast cs_sessc cs_sessp cscertcreate cscertexpire cscertexpirew cscertexpirec
	fi
# Gateway Api Call
if [[ -n "$enable_gw" || -n "$enable_all" ]]; then
	gw_buffer=`${api_cmd_get}/rest/monitor/gateways -H "${CURL_OPTS_AUTH}" -H "${CURL_OPTS_JSON}"`
	if [[ "${gw_buffer}" != "[]" ]]; then
	# Lets declare some doomsday arrays for the Gateway Infos :P
	declare -a gw_id
	declare -a gw_ip
	declare -a gw_int
	declare -a gw_type
	declare -a gw_version
	declare -a gw_name
	declare -a gw_activeconn
	declare -a gw_blastconn
	declare -a gw_pcoipconn
	declare -a gw_status
	gw_id=(` echo "${gw_buffer}" | "${JQ}" --unbuffered -r '.[].id' | "${AWK}" 1 ORS=' ' `)
	gw_ip=( `echo "${gw_buffer}" | ${JQ} -r '.[].details.address' | "${AWK}" 1 ORS=' '` )
	gw_int=( `echo "${gw_buffer}" | ${JQ} -r '.[].details.internal' | "${AWK}" 1 ORS=' '` )
	gw_type=( `echo "${gw_buffer}" | ${JQ} -r '.[].details.type' | "${AWK}" 1 ORS=' ' ` )
	gw_version=( `echo "${gw_buffer}" | ${JQ} -r '.[].details.version' | "${AWK}" 1 ORS=' ' ` )
	gw_name=( `echo "${gw_buffer}" | ${JQ} -r '.[].name' | ${AWK} 1 ORS=' ' ` )
	gw_activeconn=( `echo "${gw_buffer}" | ${JQ} -r '.[].active_connection_count' | "${AWK}" 1 ORS=' ' ` )
	gw_blastconn=( `echo "${gw_buffer}" | ${JQ} -r '.[].blast_connection_count' | "${AWK}" 1 ORS=' ' ` )
	gw_pcoipconn=( `echo "${gw_buffer}" | ${JQ} -r '.[].pcoip_connection_count' | "${AWK}" 1 ORS=' ' ` )
	gw_status=( `echo "${gw_buffer}"  | "${JQ}" --unbuffered -r '.[].status' | "${AWK}" 1 ORS=' ' ` )
	for count in "${!gw_id[@]}"
		do
		if [[ "${gw_int[count]}" == "true" ]]; then
		gw_int_2="internal"
		else
		gw_int_2="external"
		fi
		if [[ -n "${verbose}" ]]; then 
		horizon_output+="Status of Unified Access Gateway: ${gw_name[count]}\n---------------------------------------\n"
		fi
		if [[ "${gw_status[count]}" == "NOT_CONTACTED" ]]; then
			horizon_output+="[UNKNOWN] - Status of ${gw_name[count]} (Version: ${gw_version[count]} Type: ${gw_type[count]} Location: ${gw_int_2}) is ${gw_status[count]}\n"
			horizon_problem_output+="[UNKNOWN] - Unified Access Gateway - Status of ${gw_name[count]} (Version: ${gw_version[count]} Type: ${gw_type[count]} Location: ${gw_int_2}) is ${gw_status[count]}\n"
		elif [[ "${gw_status[count]}" == "PROBLEM" ]]; then
			horizon_output+="[CRITICAL] - Status of ${gw_name[count]} (Version: ${gw_version[count]} Type: ${gw_type[count]} Location: ${gw_int_2}) is ${gw_status[count]}\n"
			horizon__problem_output+="[CRITICAL] - Unified Access Gateway - Status of ${gw_name[count]} (Version: ${gw_version[count]} Type: ${gw_type[count]} Location: ${gw_int_2}) is ${gw_status[count]}\n" 
		elif [[ "${gw_status[count]}" == "STALE" ]]; then
			horizon_output+="[WARNING] - Status of ${gw_name[count]} (Version: ${gw_version[count]} Type: ${gw_type[count]} Location: ${gw_int_2}) is ${gw_status[count]}\n" 
			horizon_problem_output+="[WARNING] - Unified Access Gateway - Status of ${gw_name[count]} (Version: ${gw_version[count]} Type: ${gw_type[count]} Location: ${gw_int_2}) is ${gw_status[count]}\n"
		elif [[ "${gw_status[count]}" == "OK" ]]; then
			horizon_output+="[OK] - Status of ${gw_name[count]} (Version: ${gw_version[count]} Type: ${gw_type[count]} Location: ${gw_int_2}) is ${gw_status[count]}\n"
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - an unexpected error occured\n"
		fi
		if [[ "${gw_activeconn[count]}" -gt "${gw_current_sessions_crit}" ]]; then
			horizon_output+="[CRITICAL] - Session Count Total: ${gw_activeconn[count]}, Current Blast Connections: ${gw_blastconn[count]}, Current PCoIP Connections: ${gw_pcoipconn[count]}\n"
			horizon_problem_output+="[CRITICAL] - Unified Access Gateway - Session Count Total: ${gw_activeconn[count]}, Current Blast Connections: ${gw_blastconn[count]}, Current PCoIP Connections: ${gw_pcoipconn[count]}\n" 
		elif [[ "${gw_activeconn[count]}" -ge "${gw_current_sessions_warn}" ]]; then
			horizon_output+="[WARNING] - Session Count Total: ${gw_activeconn[count]}, Current Blast Connections: ${gw_blastconn[count]}, Current PCoIP Connections: ${gw_pcoipconn[count]}\n" 
			horizon_problem_output+="[WARNING] - Unified Access Gateway - Session Count Total: ${gw_activeconn[count]}, Current Blast Connections: ${gw_blastconn[count]}, Current PCoIP Connections: ${gw_pcoipconn[count]}\n" 
		elif [[ "${gw_activeconn[count]}" -lt "${gw_current_sessions_warn}" ]]; then
			horizon_output+="[OK] - Session Count Total: ${gw_activeconn[count]}, Current Blast Connections: ${gw_blastconn[count]}, Current PCoIP Connections: ${gw_pcoipconn[count]}\n" 
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - Unified Access Gateway - an unexpected error occured\n"
		fi
		if [[ -n "${verbose}" ]]; then 
		horizon_output+="---------------------------------------\n\n"
		fi
        	horizon_perf+=" ${gw_name[count]}_session_count_active=${gw_activeconn[count]};${gw_current_sessions_warn};${gw_current_sessions_crit}"
        	horizon_perf+=" ${gw_name[count]}_session_count_blast=${gw_blastconn[count]};0;0"
        	horizon_perf+=" ${gw_name[count]}_session_count_pcoip=${gw_pcoipconn[count]};0;0"
	done
	else
	gw_notset="No Gateways Configured"
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Status of Unified Access Gateways:\n---------------------------------------\n[OK] - ${gw_notset}\n"
  		horizon_output+="---------------------------------------\n\n"
		fi
	fi
	if [[ -z ${gw_notset} ]]; then
	unset gw_id gw_ip gw_int gw_type gw_version gw_name gw_activeconn gw_blastconn gw_pcoipconn gw_status	
	fi
fi

# AD-Domain Api Call
if [[ -n "$enable_ad" || -n "$enable_all" ]]; then
	ad_buffer=`${api_cmd_get}/rest/monitor/ad-domains -H "${CURL_OPTS_AUTH}" -H "${CURL_OPTS_JSON}"`
	if [[ "${ad_buffer}" != "[]" ]]; then
	# Lets declare some doomsday arrays for the Gateway Infos :P
	declare -a ad_csid
	declare -a ad_csname
	declare -a ad_csstatus
	declare -a ad_csrelation
	ad_csid=(` echo "${ad_buffer}" | "${JQ}" --unbuffered -r '.[].connection_servers[].id' | "${AWK}" 1 ORS=' ' `)
	ad_csname=(` echo "${ad_buffer}" | "${JQ}" --unbuffered -r '.[].connection_servers[].name' | "${AWK}" 1 ORS=' ' `)
	ad_csstatus=(` echo "${ad_buffer}" | "${JQ}" --unbuffered -r '.[].connection_servers[].status' | "${AWK}" 1 ORS=' ' `)
	ad_csrelation=(` echo "${ad_buffer}" | "${JQ}" --unbuffered -r '.[].connection_servers[].trust_relationship' | "${AWK}" 1 ORS=' ' `)
	ad_dns_name=` echo "${ad_buffer}" | "${JQ}" --unbuffered -r '.[].dns_name' | "${AWK}" 1 ORS=' ' `
	ad_netbios_name=` echo "${ad_buffer}" | "${JQ}" --unbuffered -r '.[].netbios_name' | "${AWK}" 1 ORS=' ' `
	ad_nt4_domain=` echo "${ad_buffer}" | "${JQ}" --unbuffered -r '.[].nt4_domain' | "${AWK}" 1 ORS=' ' `
	for count in "${!ad_csid[@]}"
                do
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Status of Active Directory on ${ad_csname[count]}:\n---------------------------------------\n"
                horizon_output+="Connection Server: ${ad_csname[count]}\n"
		fi
		if [[ "${ad_csstatus[count]}" == "UNCONTACTABLE" ]]; then
                	horizon_output+="[CRITICAL] - Domain Status: ${ad_csstatus[count]}\n"
			horizon_problem_output+="[CRITICAL] - Domain Status on ${ad_csname[count]} is  ${ad_csstatus[count]}\n"
		elif [[ "${ad_csstatus[count]}" == "CANNOT_BIND" ]]; then
                	horizon_output+="[WARNING] - Domain Status: ${ad_csstatus[count]}\n"
			horizon_problem_output+="[WARNING] - Domain Status on ${ad_csname[count]} is  ${ad_csstatus[count]}\n"
		elif [[ "${ad_csstatus[count]}" == "UNKNOWN" ]]; then
                	horizon_output+="[UNKNOWN] - Domain Status: ${ad_csstatus[count]}\n"
			horizon_problem_output+="[UNKNOWN] - Domain Status on ${ad_csname[count]} is  ${ad_csstatus[count]}\n"
		elif [[ "${ad_csstatus[count]}" == "FULLY_ACCESSIBLE" ]]; then
                	horizon_output+="[OK] - Domain Status: ${ad_csstatus[count]}\n"
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - an unexpected error occured\n"
		fi
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Domain Relation: ${ad_csrelation[count]}\n"
                horizon_output+="Domain DNS Name: ${ad_dns_name}\n"
                horizon_output+="Domain Netbios Name: ${ad_netbios_name}\n"
                horizon_output+="Domain is NT4 Domain: ${ad_nt4_domain}\n"
		fi
		if [[ -n "${verbose}" ]]; then 
	 	horizon_output+="---------------------------------------\n\n"
		fi
	done
	else
	ad_notset="No Active Directory Configured"
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Status of Active Directory:\n---------------------------------------\n[OK] - ${ad_notset}\n"
  		horizon_output+="---------------------------------------\n\n"
		fi
	fi
	if [[ -z ${ad_notset} ]]; then
	unset ad_csid ad_csname ad_csstatus ad_csrelation ad_dns_name ad_netbios_name ad_nt4_domain
	fi
fi
# Database Api Call
if [[ -n "$enable_db" || -n "$enable_all" ]]; then
        db_buffer=`${api_cmd_get}/rest/monitor/event-database -H "${CURL_OPTS_AUTH}" -H "${CURL_OPTS_JSON}"`
	if [[ "${db_buffer}" != "[]" ]]; then
        db_name=` echo "${db_buffer}" | "${JQ}" --unbuffered -r '.details.database_name'  `
        db_port=` echo "${db_buffer}" | "${JQ}" --unbuffered -r '.details.port'  `
        db_prefix=` echo "${db_buffer}" | "${JQ}" --unbuffered -r '.details.prefix'  `
        db_server_name=` echo "${db_buffer}" | "${JQ}" --unbuffered -r '.details.server_name'  `
        db_type=` echo "${db_buffer}" | "${JQ}" --unbuffered -r '.details.type'  `
        db_user=` echo "${db_buffer}" | "${JQ}" --unbuffered -r '.details.user_name'  `
        db_events=` echo "${db_buffer}" | "${JQ}" --unbuffered -r '.event_count' `
        db_status=` echo "${db_buffer}" | "${JQ}" --unbuffered -r '.status' `
		if [[ "${db_prefix}" ]]; then
		db_prefix="no prefix configured"
		fi
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Status of Horizon EventDB:\n---------------------------------------\n"
		fi
		if [[ "${db_status}" == "DISCONNECTED" || "${db_status}" == "ERROR" ]]; then
			if [[ -n "${verbose}" ]]; then 
                	horizon_output+="[CRITICAL] - Database Status: ${db_status} \nDB-Host: ${db_server_name}\nDB-Port: ${db_port}\nDB-Type: ${db_type}\nDatabase: ${db_name}\nDB-Prefix: ${db_prefix}\nDB-User: ${db_user}\nDB-Events: ${db_events}\n" 
			else
			horizon_output+="[CRITICAL] - Database Status: ${db_status} \n"
			fi
			horizon_problem_output+="[CRITICAL] - Database Status: ${db_status} (DB-Host: ${db_server_name}:${db_port} DB-Type: ${db_type} Database: ${db_name}\n"
		elif [[ "${db_status}" == "RECONNECTING" ]]; then
			if [[ -n "${verbose}" ]]; then 
                	horizon_output+="[WARNING] - Database Status: ${db_status} \nDB-Host: ${db_server_name}\nDB-Port: ${db_port}\nDB-Type: ${db_type}\nDatabase: ${db_name}\nDB-Prefix: ${db_prefix}\nDB-User: ${db_user}\nDB-Events: ${db_events}\n" 
			else
			horizon_output+="[WARNING] - Database Status: ${db_status} \n"
			fi
			horizon_problem_output+="[WARNING] - Database Status: ${db_status} (DB-Host: ${db_server_name}:${db_port} DB-Type: ${db_type} Database: ${db_name}\n"
		elif [[ "${db_status}" == "UNKNOWN" ]]; then
			if [[ -n "${verbose}" ]]; then 
                	horizon_output+="[UNKNOWN] - Database Status: ${db_status} \nDB-Host: ${db_server_name}\nDB-Port: ${db_port}\nDB-Type: ${db_type}\nDatabase: ${db_name}\nDB-Prefix: ${db_prefix}\nDB-User: ${db_user}\nDB-Events: ${db_events}\n" 
			else
			horizon_output+="[UNKNOWN] - Database Status: ${db_status} \n"
			fi
			horizon_problem_output+="[UNKNOWN] - Database Status: ${db_status} (DB-Host: ${db_server_name}:${db_port} DB-Type: ${db_type} Database: ${db_name}\n"
		elif [[ "${db_status}" == "CONNECTED" || "${db_status}" == "NOT_CONFIGURED" ]]; then
			if [[ -n "${verbose}" ]]; then 
                	horizon_output+="[OK] - Database Status: ${db_status} \nDB-Host: ${db_server_name}\nDB-Port: ${db_port}\nDB-Type: ${db_type}\nDatabase: ${db_name}\nDB-Prefix: ${db_prefix}\nDB-User: ${db_user}\nDB-Events: ${db_events}\n"
			else
			horizon_output+="[OK] - Database Status: ${db_status} \n"
			fi
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - EventDB - an unexpected error occured\n"
		fi
		if [[ -n "${verbose}" ]]; then 
	 	horizon_output+="---------------------------------------\n\n"
		fi
		if [[ -n "$enable_db" ]]; then
        	horizon_perf+=" EventDB_Events=${db_events};0;0"
		fi
	else
	db_notset="No Database Configured"
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Status of EventDB:\n---------------------------------------\n[OK] - ${db_notset}\n"
  		horizon_output+="---------------------------------------\n\n"
		fi
	fi
	if [[ -z ${db_notset} ]]; then
	unset db_buffer db_name db_port db_server_name db_type db_user db_events db_status 
	fi
fi

# vCenter Api Call
if [[ -n "$enable_vc" || -n "$enable_all" ]]; then
        vc_buffer=`${api_cmd_get}/rest/monitor/virtual-centers -H "${CURL_OPTS_AUTH}" -H "${CURL_OPTS_JSON}"`
	if [[ "${vc_buffer}" != "[]" ]]; then
	# declare some vc arrays
	declare -a vc_cs_vc_certv 
	declare -a vc_cs_id
	declare -a vc_cs_name
	declare -a vc_cs_state
	declare -a vc_cs_thumb
	declare -a vc_ds_path
	declare -a vc_ds_url
	declare -a vc_ds_id
	declare -a vc_ds_cap
	declare -a vc_ds_free
	declare -a vc_ds_state
	declare -a vc_ds_type
	declare -a vc_dp_count
	declare -a vc_api_version 
	declare -a vc_build 
	declare -a vc_version
	declare -a vc_esx_name
	declare -a vc_esx_cpu_cores
	declare -a vc_esx_cpu_mhz
	declare -a vc_esx_api_version
	declare -a vc_esx_version
	declare -a vc_esx_cluster_name
	declare -a vc_esx_mem
	declare -a vc_esx_gpu_avail
	declare -a vc_esx_state 
	declare -a vc_id
	declare -a vc_name
        # Lets declare some doomsday arrays for the Gateway Infos :P
        vc_cs_vc_certv=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].connection_servers | .[].certificate.valid? '|  "${AWK}" 1 ORS=' ' `)
        vc_cs_id=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].connection_servers[].id' | "${AWK}" 1 ORS=' ' `)
        vc_cs_name=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].connection_servers[].name' | "${AWK}" 1 ORS=' ' `)
        vc_cs_state=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].connection_servers[].status' | "${AWK}" 1 ORS=' ' `)
        vc_cs_thumb=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].connection_servers[].thumbprint_accepted' | "${AWK}" 1 ORS=' ' `)
        vc_ds_name=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].datastores | .[].details.name?' | "${AWK}" 1 ORS=' ' `)
        vc_ds_path=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].datastores | .[].details.path?' | "${AWK}" 1 ORS=' ' `)
        vc_ds_url=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].datastores | .[].details.url?' | "${AWK}" 1 ORS=' ' `)
        vc_ds_cap=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].datastores[].capacity_mb' | "${AWK}" 1 ORS=' ' `)
        vc_ds_free=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].datastores[].free_space_mb' | "${AWK}" 1 ORS=' ' `)
        vc_ds_type=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].datastores[].type' | "${AWK}" 1 ORS=' ' `)
        vc_ds_state=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].datastores[].status' | "${AWK}" 1 ORS=' ' `)
        vc_dp_count=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].desktops_count' | "${AWK}" 1 ORS=' ' `)
        vc_api_version=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].details.api_version' | "${AWK}" 1 ORS=' ' `)
        vc_build=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].details.build' | "${AWK}" 1 ORS=' ' `)
        vc_version=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].details.version' | "${AWK}" 1 ORS=' ' `)
        vc_esx_name=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].hosts[].details.name' | "${AWK}" 1 ORS=' ' `)
        vc_esx_cpu_cores=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].hosts[].cpu_core_count' | "${AWK}" 1 ORS=' ' `)
        vc_esx_cpu_mhz=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].hosts[].cpu_mhz' | "${AWK}" 1 ORS=' ' `)
        vc_esx_api_version=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].hosts[].details.api_version' | "${AWK}" 1 ORS=' ' `)
        vc_esx_version=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].hosts[].details.version' | "${AWK}" 1 ORS=' ' `)
        vc_esx_cluster_name=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].hosts[].details.cluster_name' | "${AWK}" 1 ORS=' ' `)
        vc_esx_mem=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].hosts[].memory_size_mb' | "${AWK}" 1 ORS=' ' `)
        vc_esx_gpu_avail=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].hosts[].details | has("vgpu_types")?' | "${AWK}" 1 ORS=' ' `)
        vc_esx_state=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].hosts[].status' | "${AWK}" 1 ORS=' ' `)
        vc_id=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].id' | "${AWK}" 1 ORS=' ' `)
        vc_name=(` echo "${vc_buffer}" | "${JQ}" --unbuffered -r '.[].name' | "${AWK}" 1 ORS=' ' `)
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Status of vCenter:\n---------------------------------------\n"
                horizon_output+="vCenter Name: ${vc_name}\nvCenter ID: ${vc_id}\nvCenter Build: ${vc_build}\nvCenter Version: ${vc_version}\nDesktop Pools: ${vc_dp_count}\n"
  		horizon_output+="---------------------------------------\n\n"
		fi
	for countvc in "${!vc_cs_id[@]}"
             do
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Status of ${vc_cs_name[countvc]} connection to vCenter:\n---------------------------------------\n"
		fi
		if [[ "${vc_cs_state[countvc]}" == "DOWN" || "${vc_cs_state[countvc]}" == "INVALID_CREDENTIALS" || "${vc_cs_state[countvc]}" == "NOT_YET_CONNECTED" || "${vc_cs_state[countvc]}" == "CANNOT_LOGIN" ]]; then
                	horizon_output+="[CRITICAL] - Connection Server  ${vc_cs_name[countvc]} is not connected to vcenter\n" 
			horizon_problem_output+="[CRITICAL] - Connection Server  ${vc_cs_name[countvc]} is not connected to vcenter\n"
		elif [[ "${vc_cs_state[countvc]}" == "RECONNECTING" ]]; then
                	horizon_output+="[WARNING] - Connection Server  ${vc_cs_name[countvc]} is reconnecting to vcenter\n" 
			horizon_problem_output+="[WARNING] - Connection Server  ${vc_cs_name[countvc]} is reconnecting to vcenter\n"
		elif [[ "${vc_cs_state[countvc]}" == "UNKNOWN" ]]; then
                	horizon_output+="[UNKNOWN] - Connection Server  ${vc_cs_name[countvc]}  Connection state to Virtual Center server is unknown.\n"
			horizon_problem_output+="[UNKNOWN] - Connection Server  ${vc_cs_name[countvc]}  Connection state to Virtual Center server is unknown.\n" 
		elif [[ "${vc_cs_state[countvc]}" == "OK" ]]; then
			if [[ -n "${verbose}" ]]; then 
                	horizon_output+="[OK] - ${vc_cs_name[countvc]} connected to vcenter\nvCenter Certificate valid: ${vc_cs_vc_certv[countvc]}\nCertificate Thumbprint trust: ${vc_cs_thumb[countvc]}\n"
			else
                	horizon_output+="[OK] - ${vc_cs_name[countvc]} connected to vcenter\n"
			fi
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - EventDB - an unexpected error occured\n"
		fi
		if [[ -n "${verbose}" ]]; then 
  		horizon_output+="---------------------------------------\n\n"
		fi
	     done
	for countesx in "${!vc_esx_name[@]}"
             do
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Status of ESXi Server ${vc_esx_name[countesx]}:\n---------------------------------------\n"
		fi
		if [[ "${vc_esx_state[countesx]}" == "DOWN" || "${vc_esx_state[countesx]}" == "NOT_RESPONDING" ]]; then
                	horizon_output+="[CRITICAL] - ESXi ${vc_esx_name[countesx]} is down or unreachable\n" 
                	horizon_problem_output+="[CRITICAL] - ESXi ${vc_esx_name[countesx]} is down or unreachable\n" 
		elif [[ "${vc_esx_state[countesx]}" == "CONNECTED" ]]; then
			if [[ -n "${verbose}" ]]; then 
                	horizon_output+="[OK] - Server is conneted to vcenter\nESX Name: ${vc_esx_name[countesx]}\nCluster: ${vc_esx_cluster_name[countesx]}\nAPI-Version: ${vc_esx_api_version[countesx]}\nVersion: ${vc_esx_version[countesx]}\nGPU-Available: ${vc_esx_gpu_avail[countesx]}\nCPU-Cores: ${vc_esx_cpu_cores[countesx]}\nCPU: ${vc_esx_cpu_mhz[countesx]} MHz\nMemory: ${vc_esx_mem[countesx]} MB\n" 
			else
                	horizon_output+="[OK] - ESXi Server ${vc_esx_name[countesx]} is conneted to vcenter\n"
			fi
                else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - EventDB - an unexpected error occured\n"
		fi
		if [[ -n "${verbose}" ]]; then 
  		horizon_output+="---------------------------------------\n\n"
		fi
	     done
	for countds in "${!vc_ds_name[@]}"
             do
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Status of Datastoress ${vc_ds_name[countds]}:\n---------------------------------------\n"
		fi
		if [[ "${vc_ds_state[countds]}" == "NOT_ACCESSIBLE" ]]; then 
                	horizon_output+="[CRITICAL] - Datastore ${vc_ds_name[countds]} is not accessible\n" 
			horizon_problem_output+="[CRITICAL] - Datastore ${vc_ds_name[countds]} is not accessible\n"
		elif [[ "${vc_ds_state[countds]}" == "ACCESSIBLE" ]]; then
			if [[ -n "${verbose}" ]]; then 
                	horizon_output+="[OK] - Datastore is accessible\nDatastore Name: ${vc_ds_name[countds]}\nDatastore Path: ${vc_ds_path[countds]}\nDatastore URL: ${vc_ds_url[countds]}\nDatastore FS: ${vc_ds_type[countds]}\nDatastore Capacity: ${vc_ds_cap[countds]} MB\nDatastore Free: ${vc_ds_free[countds]} MB\n" 
			else
                	horizon_output+="[OK] - Datastore ${vc_ds_name[countds]} is accessible\n"
			fi
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - EventDB - an unexpected error occured\n"
		fi
		if [[ -n "${verbose}" ]]; then 
  		horizon_output+="---------------------------------------\n\n"
		fi
	     done
	else
	vc_notset="No vCenter Configured"
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Status of vCenter:\n---------------------------------------\n[OK] - ${vc_notset}\n"
  		horizon_output+="---------------------------------------\n\n"
		fi
	fi
	if [[ -z ${vc_notset} ]]; then
	unset vc_cs_vc_certv vc_cs_id vc_cs_name vc_cs_state vc_cs_thumb vc_ds_path vc_ds_url vc_ds_id vc_ds_cap vc_ds_free vc_ds_state vc_ds_type vc_dp_count vc_api_version vc_build vc_version vc_esx_name vc_esx_cpu_cores vc_esx_cpu_mhz vc_esx_api_version vc_esx_version vc_esx_cluster_name vc_esx_mem vc_esx_gpu_avail vc_esx_state vc_id vc_name 
	fi
fi

# SAML Auth Api Call
if [[ -n "$enable_saml" || -n "$enable_all" ]]; then
	saml_buffer=`${api_cmd_get}/rest/monitor/saml-authenticators -H "${CURL_OPTS_AUTH}" -H "${CURL_OPTS_JSON}"`
	if [[ "${saml_buffer}" != "[]" ]]; then
	# Lets declare some doomsday arrays for the SAML Infos :P
	declare -a saml_cs_id 
	declare -a saml_cs_name
	declare -a saml_cs_status
	declare -a saml_cs_thumb 
	declare -a saml_adm_url 
	declare -a saml_label 
	declare -a saml_meta 
	declare -a saml_id 
	saml_cs_id=(` echo "${saml_buffer}" | "${JQ}" --unbuffered -r '.[].connection_servers[].id' | "${AWK}" 1 ORS=' ' `)
	saml_cs_name=(` echo "${saml_buffer}" | "${JQ}" --unbuffered -r '.[].connection_servers[].name' | "${AWK}" 1 ORS=' ' `)
	saml_cs_status=(` echo "${saml_buffer}" | "${JQ}" --unbuffered -r '.[].connection_servers[].status' | "${AWK}" 1 ORS=' ' `)
	saml_cs_thumb=(` echo "${saml_buffer}" | "${JQ}" --unbuffered -r '.[].connection_servers[].thumbprint_accepted' | "${AWK}" 1 ORS=' ' `)
	saml_adm_url=` echo "${saml_buffer}" | "${JQ}" --unbuffered -r '.[].details.administrator_url' | "${AWK}" 1 ORS=' ' `
	saml_label=` echo "${saml_buffer}" | "${JQ}" --unbuffered -r '.[].details.label' | "${AWK}" 1 ORS=' ' `
	saml_meta=` echo "${saml_buffer}" | "${JQ}" --unbuffered -r '..[].details.metadata_url' | "${AWK}" 1 ORS=' ' `
	saml_id=` echo "${saml_buffer}" | "${JQ}" --unbuffered -r '.[].id' | "${AWK}" 1 ORS=' ' `
	for count in "${!saml_cs_id[@]}"
             do
                horizon_output+="SAML Status of Connection Server ${saml_cs_name[count]}:\n---------------------------------------\n"
		if [[ "${saml_cs_status[count]}" == "ERROR" ]]; then
                	horizon_output+="[CRITICAL] - Connection Server  ${saml_cs_name[count]} is not connected to SAML Auth\n" 
                	horizon_problem_output+="[CRITICAL] - Connection Server  ${saml_cs_name[count]} is not connected to SAML Auth\n" 
		elif [[ "${saml_cs_status[count]}" == "WARN" ]]; then
                	horizon_output+="[WARNING] - Connection Server  ${saml_cs_name[count]} has minor issues with SAML Auth\n" 
                	horizon_problem_output+="[WARNING] - Connection Server  ${saml_cs_name[count]} has minor issues with SAML Auth\n" 
		elif [[ "${saml_cs_status[count]}" == "UNKNOWN" ]]; then
                	horizon_output+="[UNKNOWN] - Connection Server  ${saml_cs_name[count]} State of SAML Auth is unknown\n" 
                	horizon_problem_output+="[UNKNOWN] - Connection Server  ${saml_cs_name[count]}  State of SAML Auth is unknown\n" 
		elif [[ "${saml_cs_status[count]}" == "OK" ]]; then
                	horizon_output+="[OK] - Connection Server  ${saml_cs_name[count]} SAML Auth is is working as expected.\nConnection Server Name: ${saml_cs_name[count]}\nThumbprint Accepted: ${saml_cs_thumb[count]}\nAdmin URL: ${saml_adm_url}\nLabel: ${saml_label}\nMetadata URL: ${saml_metal}\n" 
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - SAML - an unexpected error occured\n"
		fi
  		horizon_output+="---------------------------------------\n\n"
	    done
	else
	saml_notset="No Saml Configured"
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Status of SAML:\n---------------------------------------\n[OK] - ${saml_notset}\n"
  		horizon_output+="---------------------------------------\n\n"
		fi
	fi
        if [[ -z ${saml_notset} ]]; then
        unset saml_cs_id saml_cs_name saml_cs_status saml_cs_thumb saml_adm_url saml_label saml_meta saml_id= 
        fi

	
fi
# Farms Api Call
if [[ -n "$enable_farms" || -n "$enable_all" ]]; then
	farms_buffer=`${api_cmd_get}/rest/monitor/farms -H "${CURL_OPTS_AUTH}" -H "${CURL_OPTS_JSON}"`
	if [[ "${farms_buffer}" != "[]" ]]; then
	declare -a farms_app_count 
	declare -a farms_source
	declare -a farms_type
	declare -a farms_id 
	declare -a farms_name 
	declare -a farms_rdssrv_count 
	declare -a farms_status
	farms_app_count=(` echo "${farms_buffer}" | "${JQ}" --unbuffered -r '.[].application_count' | "${AWK}" 1 ORS=' ' `)
	farms_source=(` echo "${farms_buffer}" | "${JQ}" --unbuffered -r '.[].details.source' | "${AWK}" 1 ORS=' ' `)
	farms_type=(` echo "${farms_buffer}" | "${JQ}" --unbuffered -r '.[].details.type' | "${AWK}" 1 ORS=' ' `)
	farms_id=(` echo "${farms_buffer}" | "${JQ}" --unbuffered -r '.[].id' | "${AWK}" 1 ORS=' ' `)
	farms_name=(` echo "${farms_buffer}" | "${JQ}" --unbuffered -r '.[].name' | "${AWK}" 1 ORS=' ' `)
	farms_rdssrv_count=(` echo "${farms_buffer}" | "${JQ}" --unbuffered -r '.[].rds_server_count' | "${AWK}" 1 ORS=' ' `)
	farms_status=(` echo "${farms_buffer}" | "${JQ}" --unbuffered -r '.[].status' | "${AWK}" 1 ORS=' ' `)
	for count in "${!farms_id[@]}"
             do
                horizon_output+="Status of RDS Farms ${farms_name[count]}:\n---------------------------------------\n"
		if [[ "${farms_status[count]}" == "ERROR" ]]; then
                	horizon_output+="[CRITICAL] - ${farms_name[count]} is enabled. One or more server(s) (exceeding the predefined threshold) is in ERROR state, or, for Automated Farms, there could be a provisioning error\n" 
                	horizon_problem_output+="[CRITICAL] - FARM ${farms_name[count]} is enabled. One or more server(s) (exceeding the predefined threshold) is in ERROR state, or, for Automated Farms, there could be a provisioning error\n" 
		elif [[ "${farms_status[count]}" == "WARNING" ]]; then
                	horizon_output+="[WARNING] - ${farms_name[count]} is enabled. Warning is detected.\n" 
                	horizon_problem_output+="[WARNING] - ${farms_name[count]} is enabled. Warning is detected.\n" 
		elif [[ "${farms_status[count]}" == "DISABLED" ]]; then
                	horizon_output+="[WARNING] - ${farms_name[count]} is disabled.\n" 
                	horizon_problem_output+="[WARNING] - ${farms_name[count]} is disabled.\n" 
		elif [[ "${farms_status[count]}" == "OK" ]]; then
                	horizon_output+="[OK] - Farm ${farms_name[count]} is enabled.\nFarm Name: ${farms_name[count]}\nFarm APP Count: ${farms_app_count[count]}\nFarm Source: ${farms_source[count]}\nFarm Type: ${farms_type[count]}\nRDS Server Count: ${farms_rdssrv_count[count]}\n" 
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - FARMS - an unexpected error occured\n"
		fi
  		horizon_output+="---------------------------------------\n\n"
	    done
	else
	farms_notset="No RDS Farms Configured"
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Status of RDS Farms:\n---------------------------------------\n[OK] - ${farms_notset}\n"
  		horizon_output+="---------------------------------------\n\n"
		fi
	fi
	if [[ -z ${farms_notset} ]]; then
        unset farms_app_count farms_source farms_type farms_id farms_name farms_rdssrv_count farms_status 
        fi
fi
# RDS-Server Api Call
if [[ -n "$enable_rds" || -n "$enable_all" ]]; then
	rds_buffer=`${api_cmd_get}/rest/monitor/rds-servers -H "${CURL_OPTS_AUTH}" -H "${CURL_OPTS_JSON}"`
	if [[ "${rds_buffer}" != "[]" ]]; then
	declare -a rds_agent_build 
	declare -a rds_agent_version
	declare -a rds_max_session_count
	declare -a rds_os
	declare -a rds_state 
	declare -a rds_enabled 
	declare -a rds_farm_id
	declare -a rds_load_index
	declare -a rds_load_pref
	declare -a rds_name
	declare -a rds_session_count
	declare -a rds_status
	declare -a rds_id
	rds_agent_build=(` echo "${rds_buffer}" | "${JQ}" --unbuffered -r '.[].details.agent_build' | "${AWK}" 1 ORS=' ' `)
	rds_agent_version=(` echo "${rds_buffer}" | "${JQ}" --unbuffered -r '.[].details.agent_version' | "${AWK}" 1 ORS=' ' `)
	rds_max_session_count=(` echo "${rds_buffer}" | "${JQ}" --unbuffered -r '.[].details.max_sessions_count_configured' | "${AWK}" 1 ORS=' ' `)
	rds_os=(` echo "${rds_buffer}" | "${JQ}" --unbuffered -r '.[].details.operating_system' | "${AWK}" 1 ORS=' ' `)
	rds_state=(` echo "${rds_buffer}" | "${JQ}" --unbuffered -r '.[].details.state' | "${AWK}" 1 ORS=' ' `)
	rds_enabled=(` echo "${rds_buffer}" | "${JQ}" --unbuffered -r '.[].enabled' | "${AWK}" 1 ORS=' ' `)
	rds_farm_id=(` echo "${rds_buffer}" | "${JQ}" --unbuffered -r '.[].farm_id' | "${AWK}" 1 ORS=' ' `)
	rds_load_index=(` echo "${rds_buffer}" | "${JQ}" --unbuffered -r '.[].load_index' | "${AWK}" 1 ORS=' ' `)
	rds_load_pref=(` echo "${rds_buffer}" | "${JQ}" --unbuffered -r '.[].load_preference' | "${AWK}" 1 ORS=' ' `)
	rds_name=(` echo "${rds_buffer}" | "${JQ}" --unbuffered -r '.[].name' | "${AWK}" 1 ORS=' ' `)
	rds_session_count=(` echo "${rds_buffer}" | "${JQ}" --unbuffered -r '.[].session_count' | "${AWK}" 1 ORS=' ' `)
	rds_status=(` echo "${rds_buffer}" | "${JQ}" --unbuffered -r '.[].status' | "${AWK}" 1 ORS=' ' `)
	rds_id=(` echo "${rds_buffer}" | "${JQ}" --unbuffered -r '.[].id' | "${AWK}" 1 ORS=' ' `)
	for count in "${!rds_id[@]}"
             do
                horizon_output+="Status of RDS Server ${rds_name[count]}:\n---------------------------------------\n"
		if [[ "${rds_status[count]}" == "ERROR" ]]; then
                	horizon_output+="[CRITICAL] - ${rds_name[count]} is unreachable.\n" 
                	horizon_problem_output+="[CRITICAL] - RDS - ${rds_name[count]} is unreachable.\n" 
		elif [[ "${rds_status[count]}" == "WARNING" ]]; then
                	horizon_output+="[WARNING] - ${rds_name[count]} is reachable. Some applications are detected as not installed on the RDS Server.\n" 
                	horizon_problem_output+="[WARNING] - RDS - ${rds_name[count]} is reachable. Some applications are detected as not installed on the RDS Server.\n" 
		elif [[ "${rds_status[count]}" == "DISABLED" ]]; then
                	horizon_output+="[WARNING] - ${rds_name[count]} is disabled.\n" 
                	horizon_problem_output+="[WARNING] - RDS - ${rds_name[count]} is disabled.\n" 
		elif [[ "${rds_status[count]}" == "OK" ]]; then
                	horizon_output+="[OK] - ${rds_name[count]} is reachable. All Apps are running.\nRDS Name: ${rds_name[count]}\nRDS Session Count: ${rds_session_count[count]}\nRDS Max Session Count: ${rds_max_session_count[count]}\nRDS Load Preference: ${rds_load_pref[count]}\nRDS Load Index: ${rds_load_index[count]}\nRDS State: ${rds_state[count]}\nRDS Farm ID: ${rds_farm_id[count]}\nRDS Agent Version: ${rds_agent_version[count]}\nRDS Agent Build: ${rds_agent_build[count]}\nRDS OS: ${rds_os[count]}\n"
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - RDS Server - an unexpected error occured\n"
		fi
  		horizon_output+="---------------------------------------\n\n"
	   done
	else
	rds_notset="No RDS Servers Configured"
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Status of RDS Server:\n---------------------------------------\n[OK] - ${rds_notset}\n"
  		horizon_output+="---------------------------------------\n\n"
		fi
	fi
	if [[ -z ${rds_notset} ]]; then
        unset rds_agent_build rds_agent_version rds_max_session_count rds_os rds_state rds_enabled rds_farm_id rds_load_index rds_load_pref rds_name rds_session_count rds_status rds_id 
        fi
fi
# TrueSSO Api Call
if [[ -n "$enable_tsso" || -n "$enable_all" ]]; then
	tsso_buffer=`${api_cmd_get}/rest/monitor/v1/true-sso -H "${CURL_OPTS_AUTH}" -H "${CURL_OPTS_JSON}"`
	if [[ "${tsso_buffer}" != "[]" ]]; then
	declare -a tsso_domain_dns_name 
	declare -a tsso_domain_id
	declare -a tsso_domain_status
	declare -a tsso_cert_srv_name
	declare -a tsso_cert_srv_status
	declare -a tsso_enabled
	declare -a tsso_id
	declare -a tsso_name
	declare -a tsso_status
	declare -a tsso_template_name
	declare -a tsso_template_status
	declare -a tsso_pri_fqdn
	declare -a tsso_pri_id
	declare -a tsso_pri_status
	declare -a tsso_sec_fqdn
	declare -a tsso_sec_id
	declare -a tsso_sec_status
	tsso_domain_dns_name=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].ad_domain_dns_name' | "${AWK}" 1 ORS=' ' `)
	tsso_domain_id=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].ad_domain_id' | "${AWK}" 1 ORS=' ' `)
	tsso_domain_status=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].ad_domain_status' | "${AWK}" 1 ORS=' ' `)
	tsso_cert_srv_name=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].certificate_server_details[].name' | "${AWK}" 1 ORS=' ' `)
	tsso_cert_srv_status=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].certificate_server_details[].status' | "${AWK}" 1 ORS=' ' `)
	tsso_enabled=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].enabled' | "${AWK}" 1 ORS=' ' `)
	tsso_id=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].id' | "${AWK}" 1 ORS=' ' `)
	tsso_name=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].name' | "${AWK}" 1 ORS=' ' `)
	tsso_status=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].status' | "${AWK}" 1 ORS=' ' `)
	tsso_template_name=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].template_name' | "${AWK}" 1 ORS=' ' `)
	tsso_template_status=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].template_status' | "${AWK}" 1 ORS=' ' `)
	tsso_pri_fqdn=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].primary_enrollment_server.dns_name' | "${AWK}" 1 ORS=' ' `)
	tsso_pri_id=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].primary_enrollment_server.id' | "${AWK}" 1 ORS=' ' `)
	tsso_pri_status=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].primary_enrollment_server.status' | "${AWK}" 1 ORS=' ' `)
	tsso_sec_fqdn=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].secondary_enrollment_server.dns_name' | "${AWK}" 1 ORS=' ' `)
	tsso_sec_id=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '.[].secondary_enrollment_server.id' | "${AWK}" 1 ORS=' ' `)
	tsso_sec_status=(` echo "${tsso_buffer}" | "${JQ}" --unbuffered -r '[].secondary_enrollment_server.status' | "${AWK}" 1 ORS=' ' `)
	for count in "${!tsso_id[@]}"
             do
                horizon_output+="Status of TrueSSO Server ${tsso_name[count]}:\n---------------------------------------\n"
		if [[ "${tsso_status[count]}" == "ERROR" ]]; then
                	horizon_output+="[CRITICAL] - At least one component of the True SSO connector has an error.\n" 
                	horizon_problem_output+="[CRITICAL] - TrueSSO - At least one component of the True SSO connector has an error.\n" 
		elif [[ "${tsso_status[count]}" == "WARN" ]]; then
                	horizon_output+="[WARNING] - At least one component of the True SSO connector has a warning.\n" 
                	horizon_problem_output+="[WARNING] - TrueSSO - At least one component of the True SSO connector has a warning.\n" 
		elif [[ "${tsso_status[count]}" == "OK" ]]; then
                	horizon_output+="[OK] - All True SSO components are ok\nTrueSSO Name: ${tsso_name[count]}\n" 
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - TrueSSO Server - an unexpected error occured\n"
		fi
		if [[ "${tsso_enabled[count]}" == "false" ]]; then
                	horizon_output+="[WARNING] - TrueSSO is not enabled\n" 
                	horizon_problem_output+="[WARNING] - TrueSSO - TrueSSO is not enabled\n" 
		elif [[ "${tsso_enabled[count]}" == "true" ]]; then
                	horizon_output+="[OK] - TrueSSO is enabled\n" 
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - TrueSSO Server - an unexpected error occured\n"
		fi
		if [[ "${tsso_template_status[count]}" == "ERROR" ]]; then
                	horizon_output+="[CRITICAL] - At least one enrollment server reports an error on this template.\n" 
                	horizon_problem_output+="[CRITICAL] - TrueSSO - At least one enrollment server reports an error on this template.\n" 
		elif [[ "${tsso_template_status[count]}" == "WARN" ]]; then
                	horizon_output+="[WARNING] - At least one enrollment server reports a warning on this template.\n" 
                	horizon_problem_output+="[WARNING] - TrueSSO - At least one enrollment server reports a warning on this template.\n" 
		elif [[ "${tsso_template_status[count]}" == "OK" ]]; then
                	horizon_output+="[OK] - TrueSSO Template ok\nTemplate Name: ${tsso_template_name[count]}\n" 
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - TrueSSO Server - an unexpected error occured\n"
		fi
		if [[ "${tsso_domain_status[count]}" == "ERROR" ]]; then
                	horizon_output+="[CRITICAL] - Domain Status: At least one of the enrollment servers is in an error state.\n" 
                	horizon_problem_output+="[CRITICAL] - TrueSSO - Domain Status: At least one of the enrollment servers is in an error state.\n" 
		elif [[ "${tsso_domain_status[count]}" == "WARN" ]]; then
                	horizon_output+="[WARNING] - Domain Status: At least one of the enrollment servers has a warning.\n" 
                	horizon_problem_output+="[WARNING] - TrueSSO - Domain Status: At least one of the enrollment servers has a warning.\n" 
		elif [[ "${tsso_domain_status[count]}" == "OK" ]]; then
                	horizon_output+="[OK] - Domain Status is ok\nDNS Domain: ${tsso_domain_dns_name[count]}\n" 
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - TrueSSO Server - an unexpected error occured\n"
		fi
		if [[ "${tsso_pri_status[count]}" == "ERROR" ]]; then
                	horizon_output+="[CRITICAL] - The Primary Enrollment Server has an error.\n" 
                	horizon_problem_output+="[CRITICAL] - TrueSSO - The Primary Enrollment Server has an error.\n" 
		elif [[ "${tsso_pri_status[count]}" == "OK" ]]; then
                	horizon_output+="[OK] - Primary Enrollment Server is ok\nFQDN: ${tsso_pri_fqdn[count]}\n" 
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - TrueSSO Server - an unexpected error occured\n"
		fi
		if [[ "${tsso_sec_status[count]}" == "ERROR" ]]; then
                	horizon_output+="[CRITICAL] - The Secondary Enrollment Server has an error.\n" 
                	horizon_problem_output+="[CRITICAL] - TrueSSO - The Primary Enrollment Server has an error.\n" 
		elif [[ "${tsso_sec_status[count]}" == "[]" || "${tsso_sec_status[count]}" == "" ]]; then
                	horizon_output+="[WARNING] - The Secondary Enrollment Server is not configured.\n" 
                	horizon_problem_output+="[WARNING] - TrueSSO - The Secondary Enrollment Server is not configured.\n" 
		elif [[ "${tsso_sec_status[count]}" == "OK" ]]; then
                	horizon_output+="[OK] - Secondary Enrollment Server is ok\nFQDN: ${tsso_sec_fqdn[count]}\n" 
		else
			horizon_output+="[UNKNOWN] - an unexpected error occured\n"
			horizon_problem_output+="[UNKNOWN] - TrueSSO Server - an unexpected error occured\n"
		fi
  		horizon_output+="---------------------------------------\n\n"
	   done
	else
	tsso_notset="No True SSO Configured"
		if [[ -n "${verbose}" ]]; then 
                horizon_output+="Status of TrueSSO:\n---------------------------------------\n[OK] - ${tsso_notset}\n"
  		horizon_output+="---------------------------------------\n\n"
		fi
	fi
	if [[ -z ${tsso_notset} ]]; then
		unset  -a tsso_domain_dns_name tsso_domain_id tsso_domain_status tsso_cert_srv_name tsso_cert_srv_status tsso_enabled tsso_id tsso_name tsso_status tsso_template_name tsso_template_status tsso_pri_fqdn tsso_pri_id tsso_pri_status tsso_sec_fqdn tsso_sec_id tsso_sec_status
	fi
fi
# POD Api Call
if [[ -n "$enable_pod" || -n "$enable_all" ]]; then
	pod_buffer=`${api_cmd_get}/rest/monitor/v2/pods -H "${CURL_OPTS_AUTH}" -H "${CURL_OPTS_JSON}"`
	if [[ "${pod_buffer}" == "[]" || "${pod_buffer}" =~ "CPA is not initialized for the Pod" ]]; then
	pod_notset="Cloud POD Architecture is not Initialized"
		if [[ -n "${verbose}" ]]; then 
        	horizon_output+="Status of Pod:\n---------------------------------------\n[OK] - ${pod_notset}\n"
		horizon_output+="---------------------------------------\n\n"
		fi
	else
	declare -a pod_end_enabled
        declare -a pod_end_id
        declare -a pod_end_last_update
        declare -a pod_end_name
        declare -a pod_end_rtt
        declare -a pod_end_state
        declare -a pod_end_url
        declare -a pod_id
        declare -a pod_name
        declare -a pod_site_id
	pod_end_enabled=(` echo "${pod_buffer}" | "${JQ}" --unbuffered -r '.[].endpoints[].enabled' | "${AWK}" 1 ORS=' ' `)
	pod_end_id=(` echo "${pod_buffer}" | "${JQ}" --unbuffered -r '.[].endpoints[].id' | "${AWK}" 1 ORS=' ' `)
	pod_end_last_update=(` echo "${pod_buffer}" | "${JQ}" --unbuffered -r '.[].endpoints[].last_updated_timestamp' | "${AWK}" 1 ORS=' ' `)
	pod_end_name=(` echo "${pod_buffer}" | "${JQ}" --unbuffered -r '.[].endpoints[].name' | "${AWK}" 1 ORS=' ' `)
	pod_end_rtt=(` echo "${pod_buffer}" | "${JQ}" --unbuffered -r '.[].endpoints[].roundtrip_time' | "${AWK}" 1 ORS=' ' `)
	pod_end_state=(` echo "${pod_buffer}" | "${JQ}" --unbuffered -r '.[].endpoints[].status' | "${AWK}" 1 ORS=' ' `)
	pod_end_url=(` echo "${pod_buffer}" | "${JQ}" --unbuffered -r '.[].endpoints[].url' | "${AWK}" 1 ORS=' ' `)
	pod_id=(` echo "${pod_buffer}" | "${JQ}" --unbuffered -r '.[].id' | "${AWK}" 1 ORS=' ' `)
	pod_name=(` echo "${pod_buffer}" | "${JQ}" --unbuffered -r '.[].name' | "${AWK}" 1 ORS=' ' `)
	pod_site_id=(` echo "${pod_buffer}" | "${JQ}" --unbuffered -r '.[].site_id' | "${AWK}" 1 ORS=' ' `)
                horizon_output+="Status of Pod:\n---------------------------------------\n"
                horizon_output+="Pod Name:${pod_name}\nPod ID: ${pod_id}\nPod Site ID: ${pod_site_id}\n"
  		horizon_output+="---------------------------------------\n\n"
        for count in "${!pod_end_id[@]}"
             do
                horizon_output+="Status of Pod Endpoint ${pod_end_name[count]}:\n---------------------------------------\n"
                if [[ "${pod_end_state[count]}" == "OFFLINE" ]]; then
                        horizon_output+="[CRITICAL] - Pod Endpoint ${pod_end_name[count]} is offline.\n"
                        horizon_problem_output+="[CRITICAL] - Pod - Pod Endpoint ${pod_end_name[count]} is offline.\n"
                elif [[ "${pod_end_status[count]}" == "UNCHECHED" ]]; then
                        horizon_output+="[WARNING] - Pod Endpoint ${pod_end_name[count]} is online again, but functionality is not checked yet.\n"
                        horizon_problem_output+="[WARNING] - Pod Endpoint ${pod_end_name[count]} is online again, but functionality is not checked yet.\n"
                elif [[ "${pod_end_status[count]}" == "ONLINE" ]]; then
                        horizon_output+="[OK] - Pod Endpoint ${pod_end_name[count]} is online.\n"
                        horizon_problem_output+="[OK] - Pod Endpoint ${pod_end_name[count]} is online.\nEndpoint Name: ${pod_end_name[count]}\nLast Update Timestamp: ${pod_end_last_update[count]}\nRoundtrip Time: ${pod_end_rtt[count]}\nEndpoint URL: ${pod_end_url[count]}\n"
                else
                        horizon_output+="[UNKNOWN] - an unexpected error occured\n"
                        horizon_problem_output+="[UNKNOWN] - Pod Endpoint - an unexpected error occured\n"
                fi
                if [[ "${pod_end_enabled[count]}" == "false" ]]; then
                        horizon_output+="[WARNING] - Pod Endpoint is not enabled\n"
                        horizon_problem_output+="[WARNING] - Pod Endpoint is not enabled\n" 
                elif [[ "${pod_end_enabled[count]}" == "true" ]]; then
                        horizon_output+="[OK] - Pod Endpoint is enabled\n"

                else
                        horizon_output+="[UNKNOWN] - an unexpected error occured\n"
                        horizon_problem_output+="[UNKNOWN] - Pod Endpoint - an unexpected error occured\n"
                fi
                horizon_output+="---------------------------------------\n\n"
           done
	unset pod_end_enabled pod_end_id pod_end_last_update pod_end_name pod_end_rtt pod_end_state pod_end_url pod_id pod_name pod_site_id
	fi
fi
api_disconnect=`${api_cmd_post}/rest/logout -H "${CURL_OPTS_JSON}" -d '{
		"refresh_token": "'"${api_connect[1]}"'"
		}'`
if [[ ${horizon_output} =~ "[UNKNOWN]" ]]; then
state=3
	if [[ -z "${silent}" ]]; then 
	horizon_problems="One or more Problems detected:\n---------------------------------------------------------------------\n"
	horizon_problem_output+="---------------------------------------------------------------------\n\nAll Services:\n---------------------------------------------------------------------\n"
	fi
elif [[ ${horizon_output} =~ "[CRITICAL]" ]]; then
state=2

	if [[ -z "${silent}" ]]; then 
	horizon_problems="One or more Problems detected:\n---------------------------------------------------------------------\n"
	horizon_problem_output+="---------------------------------------------------------------------\n\nAll Services:\n---------------------------------------------------------------------\n"
	fi
elif [[ ${horizon_output} =~ "[WARNING]" ]]; then
state=1
	if [[ -z "${silent}" ]]; then 
	horizon_problems="One or more Problems detected:\n---------------------------------------------------------------------\n"
	horizon_problem_output+="---------------------------------------------------------------------\n\nAll Services:\n---------------------------------------------------------------------\n"
	fi
else
state=0
horizon_problems="All Services up and running"
fi

if [[ -z "${silent}" && -n "${horizon_problem_output}" ]]; then
# Return output
#if [[ -n "${horizon_problem_output}" ]]; then
        echo -e "${horizon_problems}${horizon_problem_output}${horizon_output}|${horizon_perf}"
elif [[ -n "${silent}" && -n "${horizon_problem_output}" ]]; then
        echo -e "${horizon_problem_output}|${horizon_perf}"
elif [[ -n "${silent}" && -z "${horizon_problem_output}" ]]; then
        echo -e "[OK] - All Services are fine|${horizon_perf}"
elif [[ -z "${silent}" && -z "${horizon_problem_output}" ]]; then
        echo -e "${horizon_output}|${horizon_perf}"
else
        echo -e "${horizon_output}|${horizon_perf}"
fi
exitstate=${state}
exit ${exitstate}
