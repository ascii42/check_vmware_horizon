# check_vmware_horizon
Icinga/ Nagios check for vmware Horizon

Current State: beta

This is a little monitoring-plugin (in Bash) vor check vmware horizon connection Servers.
Mandantory tools: 
- Bash
- awk
- jq
- curl

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
    Enable all available checks.
 -w, --warning <integer>
    Set WARNING status for sessions
    if --enable-all ist set, warning will match on all sessions.
 -c, --critical <integer>
    Set CRITICAL status for sessions
    if --enable-all ist set, critical will match on all sessions.
 -wCtS|--warning-cs-total-session  <integer>
    Set if you want to enable Warning on Connection Server total sessions.
    This will overwrite -w --warning
 -cCtS|--critical-cs-total-session  <integer>
    Set if you want to enable Critical on Connection Server total sessions.
    This will overwrite -c --critical <integer>
 -wCcS|--warning-cs-current-session <integer>
    Set if you want to enable Warning on Connection Server current sessions.
    This will overwrite -w --warning
 -cCcS|--critical-cs-current-session <integer>
    Set if you want to enable Critical on Connection Server current sessions.
    This will overwrite -c --critical
 -wGcS|--warning-gw-current-session <integer>
    Set if you want to enable Warning on Gateway Server current sessions.
    This will overwrite -w --warning
 -cGcS|--critical-gw-current-session <integer>
    Set if you want to enable Critical on Gateway Server current sessions.
    This will overwrite -c --critical
 -wCce|--warning-cs-cert-expire <integer>
    Set if you want to warn on Connection Server Certificate expire. (Days)
 -cCce|--critical-cs-cert-expire <integer>
    Set if you want to critical on Connection Server Certificate expire. (Days)
 -s, --silent
    Silent all extra output
 -v, --verbose
    Print extra Information
