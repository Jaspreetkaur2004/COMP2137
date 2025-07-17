#!/bin/bash

# Assignment 2 

# Color codes for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to display status messages
function status_message {
    echo -e "${BLUE}[STATUS]${NC} $1"
}

# Function to display success messages
function success_message {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to display warning messages
function warning_message {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Function to display error messages
function error_message {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Function to check if a command exists
function command_exists {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a package is installed
function package_installed {
    dpkg -l | grep -qw "$1"
}

# Function to check if a user exists
function user_exists {
    id -u "$1" >/dev/null 2>&1
}

# Function to generate SSH keys for a user
function generate_ssh_keys {
    local username=$1
    local home_dir
    home_dir=$(eval echo ~"$username")
    
    status_message "Generating SSH keys for $username..."
    
    # Generate RSA key
    if [ ! -f "$home_dir/.ssh/id_rsa" ]; then
        sudo -u "$username" ssh-keygen -t rsa -f "$home_dir/.ssh/id_rsa" -N "" -q
        cat "$home_dir/.ssh/id_rsa.pub" >> "$home_dir/.ssh/authorized_keys"
    else
        warning_message "RSA key already exists for $username"
    fi
    
    # Generate ED25519 key
    if [ ! -f "$home_dir/.ssh/id_ed25519" ]; then
        sudo -u "$username" ssh-keygen -t ed25519 -f "$home_dir/.ssh/id_ed25519" -N "" -q
        cat "$home_dir/.ssh/id_ed25519.pub" >> "$home_dir/.ssh/authorized_keys"
    else
        warning_message "ED25519 key already exists for $username"
    fi
    
    # Set proper permissions
    chown -R "$username:$username" "$home_dir/.ssh"
    chmod 700 "$home_dir/.ssh"
    chmod 600 "$home_dir/.ssh/authorized_keys"
    
    success_message "SSH keys generated for $username"
}

# Function to add additional public key for dennis
function add_dennis_key {
    local username="dennis"
    local home_dir
    home_dir=$(eval echo ~"$username")
    local dennis_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"
    
    if grep -q "$dennis_key" "$home_dir/.ssh/authorized_keys"; then
        warning_message "Additional key already exists for $username"
    else
        status_message "Adding additional key for $username..."
        echo "$dennis_key" >> "$home_dir/.ssh/authorized_keys"
        success_message "Additional key added for $username"
    fi
}

# Function to configure network settings
function configure_network {
    status_message "Configuring network settings..."
    
    # Check if Netplan file exists
    local netplan_file="/etc/netplan/50-cloud-init.yaml"
    if [ ! -f "$netplan_file" ]; then
        error_message "Netplan configuration file not found at $netplan_file"
    fi
    
    # Check if configuration is already correct
    if grep -q "192.168.16.21/24" "$netplan_file"; then
        warning_message "Network configuration already correct"
        return
    fi
    
    # Backup original file
    cp "$netplan_file" "$netplan_file.bak"
    
    # Configure the correct IP address
    sed -i '/eth1:/,/dhcp4: true/d' "$netplan_file"
    cat <<EOF >> "$netplan_file"
        eth1:
            addresses: [192.168.16.21/24]
            dhcp4: false
            optional: true
EOF
    
    # Apply network configuration
    if netplan apply; then
        success_message "Network configuration updated successfully"
    else
        error_message "Failed to apply network configuration"
    fi
}

# Function to update hosts file
function update_hosts_file {
    status_message "Updating /etc/hosts file..."
    
    # Remove any existing entry for server1
    sed -i '/server1/d' /etc/hosts
    
    # Add correct entry
    echo "192.168.16.21 server1" >> /etc/hosts
    success_message "/etc/hosts file updated"
}

# Function to install and configure required packages
function install_packages {
    local packages=("apache2" "squid")
    
    for pkg in "${packages[@]}"; do
        if package_installed "$pkg"; then
            warning_message "$pkg is already installed"
        else
            status_message "Installing $pkg..."
            apt-get install -y "$pkg" >/dev/null 2>&1
            
            if netplan apply; then
                success_message "$pkg installed successfully"
                
                # Enable and start services
                systemctl enable "$pkg" >/dev/null 2>&1
                systemctl start "$pkg" >/dev/null 2>&1
            else
                error_message "Failed to install $pkg"
            fi
        fi
    done
}

# Function to create user accounts
function create_users {
    local users=("dennis" "aubrey" "captain" "snibbles" "brownie" "scooter" "sandy" "perrier" "cindy" "tiger" "yoda")
    
    for user in "${users[@]}"; do
        if user_exists "$user"; then
            warning_message "User $user already exists"
        else
            status_message "Creating user $user..."
            useradd -m -s /bin/bash "$user"
            
            if netplan apply; then
                success_message "User $user created successfully"
                
                # Create .ssh directory
                mkdir -p "/home/$user/.ssh"
                chown "$user:$user" "/home/$user/.ssh"
                chmod 700 "/home/$user/.ssh"
                
                # Generate SSH keys
                generate_ssh_keys "$user"
            else
                error_message "Failed to create user $user"
            fi
        fi
    done
    
    # Add dennis to sudo group
    if groups dennis | grep -q '\bsudo\b'; then
        warning_message "User dennis is already in sudo group"
    else
        status_message "Adding dennis to sudo group..."
        usermod -aG sudo dennis
        success_message "dennis added to sudo group"
    fi
    
    # Add additional key for dennis
    add_dennis_key
}

# Main execution
function main {
    # Check if script is run as root
    if [ "$(id -u)" -ne 0 ]; then
        error_message "This script must be run as root"
    fi
    
    # Update package lists
    status_message "Updating package lists..."
    apt-get update >/dev/null 2>&1
    
    # Configure network
    configure_network
    
    # Update hosts file
    update_hosts_file
    
    # Install required packages
    install_packages
    
    # Create users and configure SSH keys
    create_users
    
    success_message "Server configuration completed successfully!"
}

# Execute main function
main
