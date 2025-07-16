#!/bin/bash

# Assignment 2 - Bash script to configure server1
# Author: Jaspreet (update if needed)

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)"
  exit 1
fi

# Network configuration
hostnamectl set-hostname server1

cat > /etc/netplan/01-netcfg.yaml <<EOF
network:
  version: 2
  ethernets:
    eth0:
      dhcp4: no
      addresses: [192.168.55.10/24]
      gateway4: 192.168.55.1
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
EOF

netplan apply

# Install packages
apt update && apt install -y apache2 net-tools

# Create users and set SSH keys
for user in webadmin remoteadmin; do
  if ! id "$user" &>/dev/null; then
    adduser --disabled-password --gecos "" "$user"
  fi

  mkdir -p /home/$user/.ssh
  cp /home/student/.ssh/id_ed25519.pub /home/$user/.ssh/authorized_keys
  chown -R $user:$user /home/$user/.ssh
  chmod 700 /home/$user/.ssh
  chmod 600 /home/$user/.ssh/authorized_keys
done

echo "Configuration complete. Please reboot to finalize hostname."
