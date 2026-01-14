# Ansible Playbook for BIND9 DNS Server Setup

This Ansible playbook automates the installation and configuration of a BIND9 DNS server with primary and secondary configuration on CentOS systems for the domain `local.mydomainz.id`.

## Features

- Idempotent deployment of BIND9 DNS infrastructure
- Automated primary and secondary DNS server configuration
- Template-based configuration files for flexibility
- Built-in validation of BIND configuration and zone files
- Proper service management and error handling
- Support for multiple A records for load balancing

## Prerequisites

- Ansible 2.9+ installed on the control node
- SSH access to target servers with sudo privileges
- Target servers running CentOS 7/8/9 or compatible RHEL-based system
- Network connectivity for package updates
- Port 53 (TCP/UDP) available for DNS services

## Files Included

- `bind9-setup.yml` - Main Ansible playbook
- `named.conf.j2` - Template for main BIND configuration
- `forward_zone.j2` - Template for forward DNS zone
- `reverse_zone.j2` - Template for reverse DNS zone
- `inventory.ini` - Sample inventory file
- `ansible.cfg` - Ansible configuration (optional)

## Configuration Variables

The playbook uses the following variables (defined in the playbook):

- `domain_name`: DNS domain name (default: `local.mydomainz.id`)
- `primary_ip`: IP address of primary DNS server (default: `172.30.0.53`)
- `secondary_ip`: IP address of secondary DNS server (default: `172.30.0.56`)
- `primary_hostname`: Hostname of primary DNS server (default: `ns1.local.mydomainz.id`)
- `secondary_hostname`: Hostname of secondary DNS server (default: `ns2.local.mydomainz.id`)
- `app_test_ips`: List of IP addresses for app-test records (default: [172.30.0.52, 172.30.0.53, 172.30.0.54])

## How to Use

### 1. Prepare Inventory

Update the `inventory.ini` file with your actual server details:

```ini
[dns_servers]
# Primary DNS server
primary-dns ansible_host=YOUR_PRIMARY_IP ansible_user=root

# Secondary DNS server
secondary-dns ansible_host=YOUR_SECONDARY_IP ansible_user=root
```

### 2. Run the Playbook

Execute the playbook against your DNS servers:

```bash
# Run against all DNS servers
ansible-playbook -i inventory.ini bind9-setup.yml

# Run against specific server group
ansible-playbook -i inventory.ini bind9-setup.yml --limit primary_dns

# Run with verbose output
ansible-playbook -i inventory.ini bind9-setup.yml -v

# Dry-run (check mode) to see what would change
ansible-playbook -i inventory.ini bind9-setup.yml --check
```

### 3. Customizing Variables

You can override variables using various methods:

#### Using extra-vars:
```bash
ansible-playbook -i inventory.ini bind9-setup.yml \
  -e "domain_name=mydomain.com" \
  -e "primary_ip=192.168.1.10" \
  -e "secondary_ip=192.168.1.11"
```

#### Using a variables file:
Create a `vars.yml` file:
```yaml
domain_name: "mydomain.com"
primary_ip: "192.168.1.10"
secondary_ip: "192.168.1.11"
app_test_ips:
  - "192.168.1.20"
  - "192.168.1.21"
  - "192.168.1.22"
```

Then run:
```bash
ansible-playbook -i inventory.ini bind9-setup.yml -e "@vars.yml"
```

## What the Playbook Does

1. **Verification**: Checks OS compatibility and prerequisites
2. **System Update**: Updates system packages to latest versions
3. **Package Installation**: Installs BIND9 and related utilities (`bind`, `bind-utils`)
4. **Configuration Setup**: Creates and configures `/etc/named.conf` with appropriate settings
5. **Zone Creation**: Generates forward and reverse DNS zone files with proper permissions
6. **Role Detection**: Determines if server is primary or secondary based on IP address
7. **Primary Configuration**: Sets up master zones with allow-transfer to secondary server
8. **Secondary Configuration**: Sets up slave zones with master server reference
9. **Validation**: Checks configuration syntax and zone file validity
10. **Service Management**: Starts and enables the BIND9 service
11. **Summary**: Displays configuration summary

## Files Created and Modified

### Main Configuration
- `/etc/named.conf` - Main BIND9 configuration file with primary/secondary settings
- `/etc/named.conf.backup` - Backup of original configuration file

### Zone Files (on Primary Server)
- `/var/named/local.mydomainz.id.zone` - Forward DNS zone file
- `/var/named/local.mydomainz.id.rev` - Reverse DNS zone file for 172.30.0.x network

### Slave Directory (on Secondary Server)
- `/var/named/slaves/` - Directory for slave zone files
- `/var/named/slaves/local.mydomainz.id.zone` - Downloaded master zone file
- `/var/named/slaves/local.mydomainz.id.rev` - Downloaded reverse zone file

### System Services
- `named` service enabled and started automatically

## Security Considerations

- The playbook configures `allow-transfer` to restrict zone transfers to the secondary server only
- Recursion is enabled (standard for caching resolvers)
- DNSSEC validation is enabled for enhanced security
- Access control is configured to allow queries from any client (modify as needed for production)

## Testing the Setup

After the playbook completes, you can test the DNS setup using these commands:

```bash
# Query the domain
dig @localhost local.mydomainz.id
dig @localhost local.mydomainz.id A

# Check NS records
dig @localhost local.mydomainz.id NS

# Check SOA record
dig @localhost local.mydomainz.id SOA

# Test app-test records
dig @localhost app-test.local.mydomainz.id

# Use nslookup
nslookup local.mydomainz.id localhost
nslookup ns1.local.mydomainz.id localhost
nslookup ns2.local.mydomainz.id localhost
nslookup app-test.local.mydomainz.id localhost

# Use host command
host local.mydomainz.id localhost
host app-test.local.mydomainz.id localhost
host -t mx local.mydomainz.id localhost  # Check MX records (if any)
```

## Service Management

### Basic Commands
- Start BIND: `systemctl start named`
- Stop BIND: `systemctl stop named`
- Restart BIND: `systemctl restart named`
- Check status: `systemctl status named`
- Enable on boot: `systemctl enable named`
- Disable from boot: `systemctl disable named`

### Reload Configuration
- Reload zones only: `rndc reload`
- Reload specific zone: `rndc reload zone-name`
- Re-transfer zone from master: `rndc retransfer zone-name`

## Troubleshooting

### Common Issues
- **Permission Denied**: Ensure SSH access with sudo privileges
- **Wrong OS**: Playbook only supports CentOS/RHEL/Rocky Linux
- **IP Mismatch**: Playbook will prompt for server type if IP doesn't match defaults
- **Firewall Blocking**: Ensure port 53 (TCP/UDP) is open

### Ansible-Specific Troubleshooting
- Run in check mode to see what would change: `--check`
- Use verbose output: `-vvv` for maximum verbosity
- Limit to specific hosts: `--limit hostname`
- Skip tags: `--skip-tags "validation"` to bypass validation steps

### Diagnostic Commands
- Check BIND status: `systemctl status named`
- Check BIND logs: `journalctl -u named -f`
- Validate configuration: `named-checkconf /etc/named.conf`
- Validate zone files: `named-checkzone local.mydomainz.id /var/named/local.mydomainz.id.zone`
- Check BIND error logs: `tail -f /var/log/messages | grep named`
- Test configuration: `named -t /etc/named.conf`

### Debugging Zone Transfers
- Check transfer logs: `journalctl -u named -f | grep transfer`
- Verify allow-transfer settings in named.conf
- Ensure secondary server can reach primary on port 53

## Customization

To customize the playbook for your own domain:

1. Update the variables in the playbook or use external variable files
2. Modify the `app_test_ips` list to match your requirements
3. Adjust the reverse zone network if needed by modifying the template

## Backup and Recovery

### Configuration Backup
The playbook creates a backup of the original `/etc/named.conf` file as `/etc/named.conf.backup`.

### Manual Backup
```bash
sudo cp /etc/named.conf /etc/named.conf.backup.$(date +%Y%m%d_%H%M%S)
sudo cp -r /var/named/ /var/named.backup.$(date +%Y%m%d_%H%M%S)/
```

### Restoring from Backup
```bash
sudo cp /etc/named.conf.backup /etc/named.conf
sudo systemctl restart named
```

## Monitoring and Maintenance

### Regular Checks
- Monitor service status: `systemctl status named`
- Check logs regularly: `journalctl -u named --since today`
- Verify zone transfers: `grep transfer /var/log/messages`

### Performance Tuning
- Adjust cache settings in named.conf for high-traffic environments
- Consider using views for split-horizon DNS if needed
- Monitor resource usage: `top`, `htop`, or `systemctl status named`

## Advantages Over Bash Script

- **Idempotency**: Safe to run multiple times without side effects
- **Declarative**: Defines desired state rather than procedural steps
- **Error Handling**: Comprehensive error handling and rollback capabilities
- **Scalability**: Easy to manage multiple servers simultaneously
- **Flexibility**: Easy customization through variables and conditionals
- **Reporting**: Detailed reporting of changes and status
- **Integration**: Better integration with CI/CD pipelines and automation tools