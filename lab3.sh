#!/bin/bash
# lab3.sh - Deploys configure-host.sh to servers and applies configuration

VERBOSE_FLAG=""

# Check if -verbose was passed
if [ "$1" = "-verbose" ]; then
    VERBOSE_FLAG="-verbose"
fi

# --- Server 1 ---
echo "Deploying to server1-mgmt..."
scp configure-host.sh remoteadmin@server1-mgmt:/root
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to copy configure-host.sh to server1-mgmt" >&2
    exit 1
fi

ssh remoteadmin@server1-mgmt -- /root/configure-host.sh $VERBOSE_FLAG -name loghost -ip 192.168.16.3 -hostentry webhost 192.168.16.4
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to configure server1-mgmt" >&2
    exit 1
fi

# --- Server 2 ---
echo "Deploying to server2-mgmt..."
scp configure-host.sh remoteadmin@server2-mgmt:/root
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to copy configure-host.sh to server2-mgmt" >&2
    exit 1
fi

ssh remoteadmin@server2-mgmt -- /root/configure-host.sh $VERBOSE_FLAG -name webhost -ip 192.168.16.4 -hostentry loghost 192.168.16.3
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to configure server2-mgmt" >&2
    exit 1
fi

# --- Update local /etc/hosts ---
echo "Updating local /etc/hosts..."
./configure-host.sh $VERBOSE_FLAG -hostentry loghost 192.168.16.3
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to add loghost entry locally" >&2
    exit 1
fi

./configure-host.sh $VERBOSE_FLAG -hostentry webhost 192.168.16.4
if [ $? -ne 0 ]; then
    echo "ERROR: Failed to add webhost entry locally" >&2
    exit 1
fi

echo "All configurations applied successfully."
