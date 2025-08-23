# VMware Horizon Monitoring Plugin

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)
[![Monitoring](https://img.shields.io/badge/Monitoring-Icinga%2FNagios-blue.svg)](https://icinga.com/)
[![Version](https://img.shields.io/badge/version-1.0.1-orange.svg)](CHANGELOG.md)

A comprehensive Bash-based monitoring plugin for VMware Horizon environments, compatible with Icinga and Nagios monitoring systems. This plugin monitors various Horizon components through the VMware Horizon API to ensure your virtual desktop infrastructure is running optimally.

## Features

- **Comprehensive Monitoring**: Check Connection Servers, Security Gateways, vCenter connections, databases, and more
- **API-Based**: Leverages VMware Horizon REST APIs for accurate, real-time data
- **Flexible Thresholds**: Configurable warning and critical thresholds for different metrics
- **Multiple Components**: Monitor all Horizon infrastructure components from a single plugin
- **Rich Output**: Detailed status information with clear OK/WARNING/CRITICAL states

## Prerequisites

Ensure the following tools are installed on your monitoring server:

- **bash** (4.0 or higher)
- **curl** (for API communication)
- **jq** (for JSON parsing)
- **awk** (for text processing)

### Installation on Different Platforms

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install curl jq gawk bash
```

**RHEL/CentOS/Rocky Linux:**
```bash
sudo yum install curl jq gawk bash
# or for newer versions:
sudo dnf install curl jq gawk bash
```

**Windows (PowerShell/WSL):**
```powershell
# Using Chocolatey
choco install curl jq gawk

# Or using WSL
wsl --install
# Then install packages within WSL as shown above
```

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/ascii42/check_vmware_horizon.git
   cd check_vmware_horizon
   ```

2. **Make the script executable:**
   ```bash
   chmod +x check_vmware_horizon.sh
   ```

3. **Copy to your monitoring plugins directory:**
   ```bash
   # For Icinga2
   sudo cp check_vmware_horizon.sh /usr/lib/nagios/plugins/
   
   # For Nagios
   sudo cp check_vmware_horizon.sh /usr/local/nagios/libexec/
   ```

## Usage

### Basic Syntax

```bash
./check_vmware_horizon.sh [-h] [-V] -H <hostname> [-U <username>] [-P <password>] [-D <domain>] [options] [-w <warning>] [-c <critical>] [-v]
```

### Required Parameters

| Parameter | Description |
|-----------|-------------|
| `-H, --hostname` | IP address or hostname of the Horizon Connection Server |
| `-U, --username` | Username for authentication |
| `-P, --password` | Password for authentication |
| `-D, --domain` | Active Directory domain |

### Component Checks

| Option | Description |
|--------|-------------|
| `-eCS, --enable-connectionserver` | Monitor Connection Server status |
| `-eGW, --enable-gateway` | Monitor Security Gateway status |
| `-eVC, --enable-vcenter` | Monitor vCenter connectivity |
| `-eDB, --enable-db` | Monitor Event Database connectivity |
| `-eAD, --enable-ad` | Monitor Active Directory integration |
| `-eAV, --enable-appvolume` | Monitor App Volumes |
| `-eRDS, --enable-rds` | Monitor RDS servers |
| `-eFA, --enable-farms` | Monitor RDS farms |
| `-eSA, --enable-saml` | Monitor SAML authentication |
| `-eTS, --enable-truesso` | Monitor True SSO |
| `-ePO, --enable-pod` | Monitor Pod federation |
| `-A, --enable-all` | Enable all available checks |

### Threshold Configuration

| Option | Description |
|--------|-------------|
| `-w, --warning <integer>` | General warning threshold for sessions |
| `-c, --critical <integer>` | General critical threshold for sessions |
| `-wCtS, --warning-cs-total-session` | Connection Server total session warning |
| `-cCtS, --critical-cs-total-session` | Connection Server total session critical |
| `-wCcS, --warning-cs-current-session` | Connection Server current session warning |
| `-cCcS, --critical-cs-current-session` | Connection Server current session critical |
| `-wGcS, --warning-gw-current-session` | Gateway current session warning |
| `-cGcS, --critical-gw-current-session` | Gateway current session critical |
| `-wCce, --warning-cs-cert-expire` | Certificate expiration warning (days) |
| `-cCce, --critical-cs-cert-expire` | Certificate expiration critical (days) |

### Output Options

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Enable verbose output with detailed information |
| `-s, --silent` | Suppress extra output (minimal mode) |
| `-h, --help` | Display detailed help information |
| `-V, --version` | Show version information |

## Examples

### Basic Health Check
Monitor all components with session thresholds:
```bash
./check_vmware_horizon.sh -H horizon.company.com -U admin -P SecurePass123 -D company.local -A -w 50 -c 100 -v
```

### Specific Component Monitoring
Check only Connection Servers and Gateways:
```bash
./check_vmware_horizon.sh -H horizon.company.com -U admin -P SecurePass123 -D company.local -eCS -eGW -w 30 -c 60
```

### Certificate Expiration Monitoring
Monitor certificates with custom thresholds:
```bash
./check_vmware_horizon.sh -H horizon.company.com -U admin -P SecurePass123 -D company.local -eCS -wCce 30 -cCce 7
```

### Silent Mode for Automation
Minimal output for automated monitoring:
```bash
./check_vmware_horizon.sh -H horizon.company.com -U admin -P SecurePass123 -D company.local -A -w 50 -c 100 -s
```

## Sample Output

```
Status of Connection Server: MyConnectionServer
---------------------------------------
[OK] - Status of MyConnectionServer (Version: 8.0.0 Build: 10000000) is OK
[OK] - Status of Security Gateway UP
[OK] - PCoIP Gateway UP
[OK] - BLAST Gateway UP
[OK] - Replication to peer MyConnectionServer2 is OK
[OK] - Certificate from MyConnectionServer is valid
[OK] - Default Certificate is not in use
[OK] - Certificate is valid and will expire on Tue 30 Mar 3000 12:00:00 PM CEST
[OK] - Session Count Total: 14, Current Connections: 9, Tunnel Connections: 0, Session Protocol: BLAST

Status of Unified Access Gateway: MyUAG
---------------------------------------
[OK] - Status of MyUAG (Version: 01.01 Type: UAG Location: external) is OK
[OK] - Session Count Total: 8, Current Blast Connections: 8, Current PCoIP Connections: 0

Status of Active Directory: my.domain
---------------------------------------
[OK] - Domain Status: FULLY_ACCESSIBLE
Domain Relation: PRIMARY_DOMAIN
Domain DNS Name: my.domain
Domain NetBIOS Name: MY
```

## Integration with Monitoring Systems

### Icinga2 Configuration

Create a command definition:
```icinga2
object CheckCommand "check_horizon" {
    command = [ PluginDir + "/check_vmware_horizon.sh" ]
    arguments = {
        "-H" = "$horizon_host$"
        "-U" = "$horizon_user$"
        "-P" = "$horizon_password$"
        "-D" = "$horizon_domain$"
        "-A" = { set_if = "$horizon_check_all$" }
        "-w" = "$horizon_warning$"
        "-c" = "$horizon_critical$"
        "-v" = { set_if = "$horizon_verbose$" }
    }
}
```

Create a service definition:
```icinga2
apply Service "VMware Horizon Health" {
    check_command = "check_horizon"
    vars.horizon_host = "horizon.company.com"
    vars.horizon_user = "monitoring@company.local"
    vars.horizon_password = "SecurePassword123"
    vars.horizon_domain = "company.local"
    vars.horizon_check_all = true
    vars.horizon_warning = 50
    vars.horizon_critical = 100
    vars.horizon_verbose = true
    
    assign where host.vars.horizon_monitoring == true
}
```

### Nagios Configuration

Add to your commands.cfg:
```nagios
define command {
    command_name    check_horizon
    command_line    $USER1$/check_vmware_horizon.sh -H $ARG1$ -U $ARG2$ -P $ARG3$ -D $ARG4$ -A -w $ARG5$ -c $ARG6$ -v
}
```

Add to your services.cfg:
```nagios
define service {
    use                 generic-service
    host_name           horizon-server
    service_description VMware Horizon Health
    check_command       check_horizon!horizon.company.com!monitoring@company.local!SecurePassword123!company.local!50!100
}
```

## Security Considerations

- **Credential Management**: Store credentials securely using your monitoring system's credential management features
- **Network Access**: Ensure your monitoring server can reach the Horizon Connection Server on the API port (typically 443)
- **Service Account**: Create a dedicated service account with minimal required permissions for monitoring
- **Firewall Rules**: Configure appropriate firewall rules between monitoring server and Horizon infrastructure

## Troubleshooting

### Common Issues

**Authentication Failures:**
- Verify username, password, and domain are correct
- Check if the account is locked or password expired
- Ensure the account has necessary permissions to access Horizon APIs

**Connection Timeouts:**
- Verify network connectivity to the Connection Server
- Check firewall rules on both monitoring server and Horizon server
- Confirm the Connection Server is responding on port 443

**JSON Parsing Errors:**
- Ensure `jq` is installed and accessible
- Check if the API response format has changed (version compatibility)
- Verify the Horizon server is returning valid JSON responses

### Debug Mode

Enable verbose output for troubleshooting:
```bash
./check_vmware_horizon.sh -H horizon.company.com -U admin -P password -D domain.local -A -v
```

## Contributing

Contributions are welcome! Please feel free to submit issues, feature requests, or pull requests.

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support, please:
1. Check the troubleshooting section above
2. Review existing GitHub issues
3. Create a new issue with detailed information about your environment and the problem

## 👨‍💻 Author

**Felix Longardt**
- Email: monitoring@longardt.com
- GitHub: [@ascii42](https://github.com/ascii42)

## Acknowledgments

- VMware for the Horizon API documentation
- The monitoring community for feedback and suggestions
- Contributors who have helped improve this plugin

---

**Note**: This plugin is not officially supported by VMware. Use at your own discretion and ensure thorough testing in your environment.
