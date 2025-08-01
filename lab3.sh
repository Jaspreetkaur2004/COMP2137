#!/bin/bash

# Check for verbose flag
VERBOSE=""
if [ "$1" == "-verbose" ]; then
    VERBOSE="-verbose"
fi

# Function to check command success
check_success() {
    if [ $? -ne 0 ]; then
        echo "Error: $1 failed" >&2
        exit 1
    fi
}

# Configure server1
echo "Configuring server1..."
scp configure-host.sh remoteadmin@server1-mgmt:/root/
check_success "SCP to server1"

ssh remoteadmin@server1-mgmt -- sudo /root/configure-host.sh $VERBOSE -name loghost -ip 192.168.16.3 -hostentry webhost 192.168.16.4
check_success "SSH configuration of server1"

# Configure server2
echo "Configuring server2..."
scp configure-host.sh remoteadmin@server2-mgmt:/root/
check_success "SCP to server2"

ssh remoteadmin@server2-mgmt -- sudo /root/configure-host.sh $VERBOSE -name webhost -ip 192.168.16.4 -hostentry loghost 192.168.16.3
check_success "SSH configuration of server2"

# Update local /etc/hosts
echo "Updating local /etc/hosts..."
sudo ./configure-host.sh $VERBOSE -hostentry loghost 192.168.16.3
check_success "Local host entry for loghost"
sudo ./configure-host.sh $VERBOSE -hostentry webhost 192.168.16.4
check_success "Local host entry for webhost"

echo "Configuration completed successfully!"
exit 0
