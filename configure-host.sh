#!/bin/bash

# Signal handling to ignore TERM, HUP, and INT
trap '' TERM HUP INT

# Initialize variables
VERBOSE=false
NAME=""
IP=""
HOSTENTRY_NAME=""
HOSTENTRY_IP=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -verbose)
            VERBOSE=true
            shift
            ;;
        -name)
            NAME="$2"
            shift 2
            ;;
        -ip)
            IP="$2"
            shift 2
            ;;
        -hostentry)
            HOSTENTRY_NAME="$2"
            HOSTENTRY_IP="$3"
            shift 3
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Function for verbose output
verbose_echo() {
    if [ "$VERBOSE" = true ]; then
        echo "$@"
    fi
}

# Configure hostname if -name option provided
if [ -n "$NAME" ]; then
    CURRENT_HOSTNAME=$(hostname)
    if [ "$CURRENT_HOSTNAME" != "$NAME" ]; then
        verbose_echo "Updating hostname from $CURRENT_HOSTNAME to $NAME"
        echo "$NAME" | sudo tee /etc/hostname >/dev/null
        sudo hostname "$NAME"
        logger "Hostname changed from $CURRENT_HOSTNAME to $NAME"
    else
        verbose_echo "Hostname already set to $NAME, no changes needed"
    fi
fi

# Configure IP address if -ip option provided
if [ -n "$IP" ]; then
    CURRENT_IP=$(ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    if [ "$CURRENT_IP" != "$IP" ]; then
        verbose_echo "Updating IP address from $CURRENT_IP to $IP"
        
        # Find the first netplan configuration file
        NETPLAN_FILE=$(ls /etc/netplan/*.yaml 2>/dev/null | head -1)
        if [ -z "$NETPLAN_FILE" ]; then
            echo "Error: No netplan configuration file found" >&2
            exit 1
        fi
        
        # Create backup
        sudo cp "$NETPLAN_FILE" "${NETPLAN_FILE}.bak"
        
        # Create new netplan config with proper formatting
        TEMP_FILE=$(mktemp)
        cat <<EOF | sudo tee "$TEMP_FILE" >/dev/null
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: no
      addresses: [$IP/24]
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
EOF
        
        # Replace the netplan file
        sudo mv "$TEMP_FILE" "$NETPLAN_FILE"
        sudo chmod 600 "$NETPLAN_FILE"
        
        # Apply changes
        if ! sudo netplan apply; then
            echo "Error: Failed to apply netplan changes" >&2
            sudo mv "${NETPLAN_FILE}.bak" "$NETPLAN_FILE"
            exit 1
        fi
        logger "IP address changed from $CURRENT_IP to $IP"
    else
        verbose_echo "IP address already set to $IP, no changes needed"
    fi
fi

# Configure /etc/hosts entry if -hostentry provided
if [ -n "$HOSTENTRY_NAME" ] && [ -n "$HOSTENTRY_IP" ]; then
    if ! grep -q "$HOSTENTRY_IP $HOSTENTRY_NAME" /etc/hosts; then
        verbose_echo "Adding host entry: $HOSTENTRY_IP $HOSTENTRY_NAME"
        
        # Create temp file with correct permissions
        TEMP_FILE=$(mktemp)
        sudo chmod 644 "$TEMP_FILE"
        
        # Remove existing entries and add new one
        grep -v "$HOSTENTRY_IP" /etc/hosts | grep -v "$HOSTENTRY_NAME" | sudo tee "$TEMP_FILE" >/dev/null
        echo "$HOSTENTRY_IP $HOSTENTRY_NAME" | sudo tee -a "$TEMP_FILE" >/dev/null
        
        # Replace original file
        sudo mv "$TEMP_FILE" /etc/hosts
        logger "Added host entry: $HOSTENTRY_IP $HOSTENTRY_NAME"
    else
        verbose_echo "Host entry already exists: $HOSTENTRY_IP $HOSTENTRY_NAME"
    fi
fi

exit 0
