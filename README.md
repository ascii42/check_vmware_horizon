# check_vmware_horizon
Icinga/ Nagios check for vmware Horizon

Current State: beta

This is a little monitoring-plugin (in Bash) vor check vmware horizon connection Servers.
## Requirements: 
- `Bash`
- `awk`
- `jq`
- `curl`

## Options:
```
Usage: check_vmware_horizon.sh [-h] [-V] -H <hostname> [-U <username>] [-P <password>] [-D <domain>] [-opts] [-w <warning>] [-c <critical>] [-v]

 This plugin checks several statistics of a vmware Horizon Connection Server via API.

Options:
 -h, --help
    Print detailed help screen
 -V, --version
    Print version information
 -i, --input <integer>
    Set input value to INTEGER percent
 -H, --host, --hostname <hostname>
    Set ipadress or hostname for destination
 -U, --username <username>
    Set Username for Login
 -P, --password <password>
    Set Password for Login
 -D, --domain <domain>
    Set Domain for Login
 -eCS, ---enable-connectionserver
    Enable Connection Server check
 -eGW, --enable-gateway
    Enable Gateway check
 -eVC, --enable-vcenter
    Enable vCenter check
 -eDB, --enable-db
    Enable Event DB check
 -eAD, --enable-ad
    Enable AD-Domain check
 -eRDS, --enable-rds
    Enable RDS Server check
 -eFA, --enable-farms
    Enable RDS Farms check
 -eSA, --enable-saml
    Enable RDS Farms check
 -eTS, --enable-truesso
    Enable True SSO check
 -ePO, --enable-pod
    Enable POD check
 -A, --enable-all
    Enable all available checks.
 -w, --warning <integer>
    Set WARNING status for sessions
    if --enable-all ist set, warning will match on all sessions.
 -c, --critical <integer>
    Set CRITICAL status for sessions
    if --enable-all ist set, critical will match on all sessions.
 -wCtS, --warning-cs-total-session  <integer>
    Set if you want to enable Warning on Connection Server total sessions.
    This will overwrite -w --warning
 -cCtS, --critical-cs-total-session  <integer>
    Set if you want to enable Critical on Connection Server total sessions.
    This will overwrite -c --critical <integer>
 -wCcS, --warning-cs-current-session <integer>
    Set if you want to enable Warning on Connection Server current sessions.
    This will overwrite -w --warning
 -cCcS, --critical-cs-current-session <integer>
    Set if you want to enable Critical on Connection Server current sessions.
    This will overwrite -c --critical
 -wGcS, --warning-gw-current-session <integer>
    Set if you want to enable Warning on Gateway Server current sessions.
    This will overwrite -w --warning
 -cGcS, --critical-gw-current-session <integer>
    Set if you want to enable Critical on Gateway Server current sessions.
    This will overwrite -c --critical
 -wCce, --warning-cs-cert-expire <integer>
    Set if you want to warn on Connection Server Certificate expire. (Days)
 -cCce, --critical-cs-cert-expire <integer>
    Set if you want to critical on Connection Server Certificate expire. (Days)
 -s, --silent
    Silent all extra output
 -v, --verbose
    Print extra Information
    
    Example: check_vmware_horizon.sh -H <hostname> -P <PASSWORD> -D <DOMAIN> -A -w 50 -c 100 -v

```
## Output Example (verbose):
```
Plugin Output:
Status of Connection Server: MyConnectionServer
---------------------------------------
[OK] - Status of MyConnectionServer (Version: 8.0.0 Build: 10000000) is OK
[OK] - Status of Security Gateway UP
[OK] - PCoIP Gateway UP
[OK] - BLAST Gateway UP
[OK] - Replication to peer MyConnectionServer2 is OK
[OK] - Certificate from MyConnectionServer is valid
[OK] - Default Cetificate is not in use
[OK] - Certificate is valid and will be expire on Tue 30 Mar 3000 12:00:00 PM CEST
[OK] - Session Count Total: 14, Current Connections: 9, Tunnel Connections: 0, Session Protocol: BLAST
---------------------------------------

Status of Connection Server: MyConnectionServer2
---------------------------------------
[OK] - Status of MyConnectionServer2 (Version: 8.0.0 Build: 10000000) is OK
[OK] - Status of Security Gateway UP
[OK] - PCoIP Gateway UP
[OK] - BLAST Gateway UP
[OK] - Replication to peer MyConnectionServer is OK
[OK] - Certificate from MyConnectionServer is valid
[OK] - Default Cetificate is not in use
[OK] - Certificate is valid and will be expire on Tue 30 Mar 3000 12:00:00 PM CEST
[OK] - Session Count Total: 14, Current Connections: 9, Tunnel Connections: 0, Session Protocol: BLAST
---------------------------------------

Status of Unified Access Gateway: MyUAG
---------------------------------------
[OK] - Status of MyUAG (Version: 01.01 Type: UAG Location: external) is OK
[OK]  - Session Count Total: 8, Current Blast Connections: 8, Current PCoIP Connections: 0
---------------------------------------

Status of Active Directory on MyConnectionServer:
---------------------------------------
Connection Server: MyConnectionServer
[OK] - Domain Status: FULLY_ACCESSIBLE
Domain Relation: PRIMARY_DOMAIN
Domain DNS Name: my.domain 
Domain Netbios Name: MY
Domain is NT4 Domain: false 
---------------------------------------

Status of Active Directory on MyConnectionServer2:
---------------------------------------
Connection Server: MyConnectionServer2
[OK] - Domain Status: FULLY_ACCESSIBLE
Domain Relation: PRIMARY_DOMAIN
Domain DNS Name: my.domain 
Domain Netbios Name: MY
Domain is NT4 Domain: false 
---------------------------------------

Status of Horizon EventDB:
---------------------------------------
[OK] - Database Status: CONNECTED 
DB-Host: db.my.domain
DB-Port: 5432
DB-Type: POSTGRESQL
Database: event
DB-Prefix: no prefix configured
DB-User: dbuser
DB-Events: 100000
---------------------------------------

Status of vCenter:
---------------------------------------
vCenter Name: https://vcenter.my.domain:443/sdk
vCenter ID: 0000000-0000-0000-0000-0000000000
vCenter Build: 10000000
vCenter Version: 1.0.0
Desktop Pools: 2
---------------------------------------

Status of MyConnectionServer connection to vCenter:
---------------------------------------
[OK] - MyConnectionServer connected to vcenter
vCenter Certificate valid: false
Certificate Thumbprint trust: true
---------------------------------------

Status of MyConnectionServer2 connection to vCenter:
---------------------------------------
[OK] - MyConnectionServer2 connected to vcenter
vCenter Certificate valid: false
Certificate Thumbprint trust: true
---------------------------------------

Status of ESXi Server esx.my.domain:
---------------------------------------
[OK] - Server is conneted to vcenter
ESX Name: esx.my.domain
Cluster: MyCluster
API-Version: 1.0.0.0
Version: 1.0.0
GPU-Available: true
CPU-Cores: 132
CPU: 50000 MHz
Memory: 1000000 MB
---------------------------------------
```
