#!/bin/bash

# Script to set up BIND9 DNS server with primary and secondary configuration on CentOS
# Domain: local.mydomainz.id
# Primary NS: ns1.local.mydomainz.id (172.30.0.53)
# Secondary NS: ns2.local.mydomainz.id (172.30.0.56)

set -e  # Exit on any error

# Variables
DOMAIN="local.mydomainz.id"
PRIMARY_IP="172.30.0.53"
SECONDARY_IP="172.30.0.56"
PRIMARY_HOSTNAME="ns1.local.mydomainz.id"
SECONDARY_HOSTNAME="ns2.local.mydomainz.id"
ZONEFILE_DIR="/var/named"
BIND_CONFIG_FILE="/etc/named.conf"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

# Check if running on CentOS/RHEL
check_os() {
    if ! grep -q "CentOS\|Red Hat\|Rocky" /etc/os-release; then
        print_error "This script is designed for CentOS/RHEL/Rocky Linux"
        exit 1
    fi
}

# Update system packages
update_system() {
    print_status "Updating system packages..."
    yum update -y
}

# Install BIND9
install_bind9() {
    print_status "Installing BIND9..."
    yum install -y bind bind-utils
    systemctl enable named
}

# Create zone file directory
create_zone_dir() {
    print_status "Creating zone file directory..."
    mkdir -p $ZONEFILE_DIR
    chown named:named $ZONEFILE_DIR
    chmod 755 $ZONEFILE_DIR
}

# Configure BIND9 options
configure_bind_options() {
    print_status "Configuring BIND9 options..."
    
    # Backup original config
    cp /etc/named.conf /etc/named.conf.backup
    
    # Create new named.conf
    cat > /etc/named.conf << EOF
//
// named.conf
//
// Provided by Red Hat bind package to configure the ISC BIND named(8) DNS
// server as a caching only nameserver (as a localhost DNS resolver only).
//
// See /usr/share/doc/bind*/sample/ for example named configuration files.
//

options {
    listen-on port 53 { any; };
    listen-on-v6 port 53 { any; };
    directory       "/var/named";
    dump-file       "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    recursing-file  "/var/named/data/named.recursing";
    secroots-file   "/var/named/data/named.secroots";
    allow-query     { any; };

    /*
     - If you are building an AUTHORITATIVE DNS server, do NOT enable recursion.
     - If you are building a RECURSIVE (caching) DNS server, you need to enable
       recursion.
     - If your recursive DNS server has a public IP address, you MUST enable access
       control to limit queries to your legitimate users. Failing to do so will
       cause your server to become part of large scale DNS amplification
       attacks. Implementing BCP38 within your network would greatly
       reduce such attack surface
    */
    recursion yes;

    dnssec-enable yes;
    dnssec-validation yes;

    /* Add entries below this line for slave zones */
    allow-transfer { $SECONDARY_IP; };

    /* Path to ISC DLV key */
    bindkeys-file "/etc/named.iscdlv.key";

    managed-keys-directory "/var/named/dynamic";

    pid-file "/run/named/named.pid";
    session-keyfile "/run/named/session.key";
};

logging {
        channel default_debug {
                file "data/named.run";
                severity dynamic;
        };
};

zone "." IN {
    type hint;
    file "named.ca";
};

include "/etc/named.rfc1912.zones";
include "/etc/named.root.key";
EOF
}

# Configure primary DNS server
configure_primary() {
    print_status "Configuring primary DNS server..."
    
    # Append zone configuration to named.conf
    cat >> /etc/named.conf << EOF

// Primary zone configuration
zone "$DOMAIN" IN {
    type master;
    file "$DOMAIN.zone";
    allow-transfer { $SECONDARY_IP; };
    notify yes;
};

// Reverse zone for 172.30.0.x network
zone "0.30.172.in-addr.arpa" IN {
    type master;
    file "$DOMAIN.rev";
    allow-transfer { $SECONDARY_IP; };
    notify yes;
};
EOF

    # Create forward zone file
    create_forward_zone_file
    
    # Create reverse zone file
    create_reverse_zone_file
}

# Create forward zone file
create_forward_zone_file() {
    print_status "Creating forward zone file..."
    
    # Generate serial number (current timestamp)
    SERIAL=$(date +%Y%m%d01)
    
    cat > $ZONEFILE_DIR/$DOMAIN.zone << EOF
\$TTL 1D
@       IN SOA  $PRIMARY_HOSTNAME. admin.$DOMAIN. (
                                $SERIAL     ; Serial
                                1D          ; Refresh
                                1H          ; Retry
                                1W          ; Expire
                                3H )        ; Minimum TTL
        IN NS   $PRIMARY_HOSTNAME.
        IN NS   $SECONDARY_HOSTNAME.
$PRIMARY_HOSTNAME.    IN A    $PRIMARY_IP
$SECONDARY_HOSTNAME.  IN A    $SECONDARY_IP

; A records for app-test service
app-test                IN A    172.30.0.52
app-test                IN A    172.30.0.53
app-test                IN A    172.30.0.54

; Add any additional records here
www     IN CNAME @
EOF

    chown named:named $ZONEFILE_DIR/$DOMAIN.zone
    chmod 644 $ZONEFILE_DIR/$DOMAIN.zone
}

# Create reverse zone file
create_reverse_zone_file() {
    print_status "Creating reverse zone file..."
    
    SERIAL=$(date +%Y%m%d01)
    
    cat > $ZONEFILE_DIR/$DOMAIN.rev << EOF
\$TTL 1D
@       IN SOA  $PRIMARY_HOSTNAME. admin.$DOMAIN. (
                                $SERIAL     ; Serial
                                1D          ; Refresh
                                1H          ; Retry
                                1W          ; Expire
                                3H )        ; Minimum TTL
        IN NS   $PRIMARY_HOSTNAME.
        IN NS   $SECONDARY_HOSTNAME.
53      IN PTR  $PRIMARY_HOSTNAME.
56      IN PTR  $SECONDARY_HOSTNAME.
EOF

    chown named:named $ZONEFILE_DIR/$DOMAIN.rev
    chmod 644 $ZONEFILE_DIR/$DOMAIN.rev
}

# Configure secondary DNS server
configure_secondary() {
    print_status "Configuring secondary DNS server..."
    
    # Append zone configuration to named.conf
    cat >> /etc/named.conf << EOF

// Secondary zone configuration
zone "$DOMAIN" IN {
    type slave;
    masters { $PRIMARY_IP; };
    file "slaves/$DOMAIN.zone";
};

// Reverse zone for 172.30.0.x network
zone "0.30.172.in-addr.arpa" IN {
    type slave;
    masters { $PRIMARY_IP; };
    file "slaves/$DOMAIN.rev";
};
EOF

    # Create slaves directory
    mkdir -p $ZONEFILE_DIR/slaves
    chown named:named $ZONEFILE_DIR/slaves
    chmod 755 $ZONEFILE_DIR/slaves
}

# Check if this server is primary or secondary based on IP
determine_server_type() {
    # Get the primary IP of the current server
    CURRENT_IP=$(hostname -I | awk '{print $1}')
    
    if [[ "$CURRENT_IP" == "$PRIMARY_IP" ]]; then
        print_status "Detected as PRIMARY DNS server ($PRIMARY_HOSTNAME)"
        SERVER_TYPE="primary"
    elif [[ "$CURRENT_IP" == "$SECONDARY_IP" ]]; then
        print_status "Detected as SECONDARY DNS server ($SECONDARY_HOSTNAME)"
        SERVER_TYPE="secondary"
    else
        print_warning "Current IP ($CURRENT_IP) doesn't match primary ($PRIMARY_IP) or secondary ($SECONDARY_IP) IP"
        print_warning "Please specify server type: primary or secondary"
        read -p "Enter server type (primary/secondary): " SERVER_TYPE
        while [[ "$SERVER_TYPE" != "primary" && "$SERVER_TYPE" != "secondary" ]]; do
            read -p "Invalid input. Enter server type (primary/secondary): " SERVER_TYPE
        done
    fi
}

# Validate BIND configuration
validate_config() {
    print_status "Validating BIND configuration..."
    
    # Check named.conf syntax
    if named-checkconf; then
        print_status "named.conf syntax is OK"
    else
        print_error "named.conf syntax error"
        exit 1
    fi
    
    # Check zone files if on primary
    if [[ "$SERVER_TYPE" == "primary" ]]; then
        if command -v named-checkzone >/dev/null 2>&1; then
            if named-checkzone $DOMAIN $ZONEFILE_DIR/$DOMAIN.zone; then
                print_status "Zone file for $DOMAIN is OK"
            else
                print_error "Zone file for $DOMAIN has errors"
                exit 1
            fi
        else
            print_warning "named-checkzone command not found, skipping zone validation"
        fi
    fi
}

# Restart BIND service
restart_bind() {
    print_status "Restarting BIND9 service..."
    systemctl restart named
    systemctl status named --no-pager -l
}

# Display configuration summary
display_summary() {
    print_status "DNS Configuration Summary:"
    echo "Domain: $DOMAIN"
    echo "Primary NS: $PRIMARY_HOSTNAME ($PRIMARY_IP)"
    echo "Secondary NS: $SECONDARY_HOSTNAME ($SECONDARY_IP)"
    echo "A records for app-test: 172.30.0.52, 172.30.0.53, 172.30.0.54"
    echo ""
    print_status "To test DNS resolution, you can use:"
    echo "  dig @localhost $DOMAIN"
    echo "  dig @localhost app-test.$DOMAIN"
    echo "  nslookup $DOMAIN localhost"
    echo "  nslookup app-test.$DOMAIN localhost"
    echo "  host $DOMAIN localhost"
    echo "  host app-test.$DOMAIN localhost"
}

# Main function
main() {
    print_status "Starting BIND9 DNS server setup on CentOS..."
    
    check_root
    check_os
    update_system
    install_bind9
    create_zone_dir
    configure_bind_options
    determine_server_type
    
    if [[ "$SERVER_TYPE" == "primary" ]]; then
        configure_primary
    else
        configure_secondary
    fi
    
    validate_config
    restart_bind
    display_summary
    
    print_status "BIND9 DNS server setup completed!"
}

# Run main function
main "$@"