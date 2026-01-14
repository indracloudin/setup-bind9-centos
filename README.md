# BIND9 DNS Server Setup for CentOS

This script automates the installation and configuration of a BIND9 DNS server with primary and secondary configuration on CentOS systems for the domain `local.mydomainz.id`.

## Features

- Automated installation and configuration of BIND9 DNS server
- Primary and secondary DNS server setup with automatic detection
- Forward and reverse DNS zone creation
- Automatic serial number generation for zone files
- Configuration validation and service management
- Support for multiple A records for load balancing

## Prerequisites

- CentOS 7/8/9 or compatible RHEL-based system (Rocky Linux also supported)
- Running on either the primary server (172.30.0.53) or secondary server (172.30.0.56)
- Root or sudo access
- Network connectivity for package updates
- Port 53 (TCP/UDP) available for DNS services

## Configuration Details

- **Domain**: `local.mydomainz.id`
- **Primary NS**: `ns1.local.mydomainz.id` (IP: 172.30.0.53)
- **Secondary NS**: `ns2.local.mydomainz.id` (IP: 172.30.0.56)
- **Network Range**: 172.30.0.x (for reverse DNS)
- **A Records for app-test**:
  - `app-test.local.mydomainz.id` → 172.30.0.52
  - `app-test.local.mydomainz.id` → 172.30.0.53
  - `app-test.local.mydomainz.id` → 172.30.0.54
- **Additional Records**:
  - `www.local.mydomainz.id` → CNAME to `local.mydomainz.id`

## How to Use

### Basic Installation

1. Transfer the script to your CentOS server:
   ```bash
   scp setupbind9.sh root@your-server:/tmp/
   ```

2. Make the script executable:
   ```bash
   chmod +x /tmp/setupbind9.sh
   ```

3. Run the script as root:
   ```bash
   sudo /tmp/setupbind9.sh
   ```

### Manual Server Type Selection

If your server IP doesn't match the predefined IPs (172.30.0.53 or 172.30.0.56), the script will prompt you to specify the server type:
- Enter `primary` for the primary DNS server
- Enter `secondary` for the secondary DNS server

## What the Script Does

1. **System Verification**: Checks if running as root and verifies OS compatibility
2. **System Update**: Updates system packages to latest versions
3. **Package Installation**: Installs BIND9 and related utilities (`bind`, `bind-utils`)
4. **Configuration Setup**: Creates and configures `/etc/named.conf` with appropriate settings
5. **Zone Creation**: Generates forward and reverse DNS zone files with proper permissions
6. **Automatic Detection**: Determines if server is primary or secondary based on IP address
7. **Primary Configuration**: Sets up master zones with allow-transfer to secondary server
8. **Secondary Configuration**: Sets up slave zones with master server reference
9. **Validation**: Checks configuration syntax and zone file validity
10. **Service Management**: Starts and enables the BIND9 service
11. **Summary Display**: Shows configuration summary and testing commands

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

- The script configures `allow-transfer` to restrict zone transfers to the secondary server only
- Recursion is enabled (standard for caching resolvers)
- DNSSEC validation is enabled for enhanced security
- Access control is configured to allow queries from any client (modify as needed for production)

## Testing the Setup

After the script completes, you can test the DNS setup using these commands:

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

## Zone File Management

### Incrementing Serial Numbers
The script automatically generates serial numbers based on the current date (YYYYMMDD01 format). When manually updating zone files:
1. Increment the serial number in the SOA record
2. Reload the zone: `rndc reload domain.name`

### Adding New Records
Edit the zone file on the primary server:
```bash
sudo vi /var/named/local.mydomainz.id.zone
```

Then reload the zone:
```bash
sudo rndc reload local.mydomainz.id
```

## Troubleshooting

### Common Issues
- **Permission Denied**: Ensure running as root
- **Wrong OS**: Script only supports CentOS/RHEL/Rocky Linux
- **IP Mismatch**: Manually specify server type if IP doesn't match defaults
- **Firewall Blocking**: Ensure port 53 (TCP/UDP) is open

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

To customize the script for your own domain:

1. Edit the variables section at the top of the script:
   - `DOMAIN`: Change to your domain name
   - `PRIMARY_IP`: Change to your primary server IP
   - `SECONDARY_IP`: Change to your secondary server IP
   - `PRIMARY_HOSTNAME`: Change to your primary hostname
   - `SECONDARY_HOSTNAME`: Change to your secondary hostname

2. Modify the A records in the `create_forward_zone_file()` function to match your requirements

3. Adjust the reverse zone network in the `create_reverse_zone_file()` function if needed

## Backup and Recovery

### Configuration Backup
The script creates a backup of the original `/etc/named.conf` file as `/etc/named.conf.backup`.

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

## Alternative: Ansible Playbook

As an alternative to the bash script, we now provide an Ansible playbook for managing BIND9 DNS server deployments. The Ansible approach offers several advantages:

### Advantages of Ansible Approach

- **Idempotency**: Safe to run multiple times without side effects
- **Declarative**: Defines desired state rather than procedural steps
- **Error Handling**: Comprehensive error handling and rollback capabilities
- **Scalability**: Easy to manage multiple servers simultaneously
- **Flexibility**: Easy customization through variables and conditionals
- **Reporting**: Detailed reporting of changes and status
- **Integration**: Better integration with CI/CD pipelines and automation tools

### Ansible Files Included

- `bind9-setup.yml` - Main Ansible playbook
- `named.conf.j2` - Template for main BIND configuration
- `forward_zone.j2` - Template for forward DNS zone
- `reverse_zone.j2` - Template for reverse DNS zone
- `inventory.ini` - Sample inventory file
- `ANSIBLE-README.md` - Detailed documentation for Ansible playbook

### How to Use the Ansible Playbook

1. Install Ansible on your control machine:
   ```bash
   pip install ansible
   ```

2. Update the `inventory.ini` file with your server details:
   ```ini
   [dns_servers]
   # Primary DNS server
   primary-dns ansible_host=YOUR_PRIMARY_IP ansible_user=root

   # Secondary DNS server
   secondary-dns ansible_host=YOUR_SECONDARY_IP ansible_user=root
   ```

3. Run the playbook:
   ```bash
   ansible-playbook -i inventory.ini bind9-setup.yml
   ```

For complete documentation on using the Ansible playbook, see `ANSIBLE-README.md`.

## Version Information

- **Script Version**: Auto-generated based on date
- **BIND Version**: Latest available in CentOS repositories
- **Last Updated**: January 2026