#!/bin/bash
# configure-host.sh - Configures basic host settings

# Ignore TERM, HUP, INT signals
trap '' TERM HUP INT

VERBOSE=false

verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "$1"
    fi
}

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -verbose)
            VERBOSE=true
            shift
            ;;
        -name)
            DESIRED_NAME="$2"
            shift 2
            ;;
        -ip)
            DESIRED_IP="$2"
            shift 2
            ;;
        -hostentry)
            ENTRY_NAME="$2"
            ENTRY_IP="$3"
            shift 3
            ;;
        *)
            echo "Unknown option: $1" >&2
            shift
            ;;
    esac
done

# -name: Set hostname
if [ -n "$DESIRED_NAME" ]; then
    CURRENT_NAME=$(hostname)
    if [ "$CURRENT_NAME" != "$DESIRED_NAME" ]; then
        verbose "Changing hostname from '$CURRENT_NAME' to '$DESIRED_NAME'"

        # Update /etc/hostname
        echo "$DESIRED_NAME" > /etc/hostname

        # Update /etc/hosts - replace old hostname with new
        sed -i "s/\b$CURRENT_NAME\b/$DESIRED_NAME/g" /etc/hosts

        # Apply hostname to running system
        hostnamectl set-hostname "$DESIRED_NAME"

        logger "configure-host.sh: hostname changed from '$CURRENT_NAME' to '$DESIRED_NAME'"
    else
        verbose "Hostname is already '$DESIRED_NAME', no change needed"
    fi
fi

# -ip: Set IP address on lan interface
if [ -n "$DESIRED_IP" ]; then
    # Detect the LAN interface (not lo, not the mgmt interface)
    LAN_IFACE=$(ip -o link show | awk -F': ' '{print $2}' | grep -v lo | grep -v "@" | tail -1)

    CURRENT_IP=$(ip -4 addr show "$LAN_IFACE" 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

    if [ "$CURRENT_IP" != "$DESIRED_IP" ]; then
        verbose "Changing IP on $LAN_IFACE from '$CURRENT_IP' to '$DESIRED_IP'"

        # Update /etc/hosts
        if grep -q "$CURRENT_IP" /etc/hosts; then
            sed -i "s/$CURRENT_IP/$DESIRED_IP/g" /etc/hosts
        fi

        # Update netplan config
        NETPLAN_FILE=$(grep -rl "$LAN_IFACE" /etc/netplan/ 2>/dev/null | head -1)
        if [ -z "$NETPLAN_FILE" ]; then
            NETPLAN_FILE="/etc/netplan/10-lxc.yaml"
        fi

        if [ -f "$NETPLAN_FILE" ]; then
            sed -i "s|[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+/[0-9]\+|$DESIRED_IP/24|g" "$NETPLAN_FILE"
        else
            verbose "Warning: Could not find netplan file to update"
        fi

        # Apply new IP
        netplan apply 2>/dev/null || true

        logger "configure-host.sh: IP on $LAN_IFACE changed from '$CURRENT_IP' to '$DESIRED_IP'"
    else
        verbose "IP on $LAN_IFACE is already '$DESIRED_IP', no change needed"
    fi
fi

# -hostentry: Add/update entry in /etc/hosts
if [ -n "$ENTRY_NAME" ] && [ -n "$ENTRY_IP" ]; then
    if grep -qP "^\s*$ENTRY_IP\s+$ENTRY_NAME(\s|$)" /etc/hosts; then
        verbose "Host entry '$ENTRY_IP $ENTRY_NAME' already exists, no change needed"
    else
        # Remove any existing entry for this name or IP
        sed -i "/\b$ENTRY_NAME\b/d" /etc/hosts
        sed -i "/^$ENTRY_IP\s/d" /etc/hosts

        # Add new entry
        echo "$ENTRY_IP $ENTRY_NAME" >> /etc/hosts

        verbose "Added host entry: '$ENTRY_IP $ENTRY_NAME'"
        logger "configure-host.sh: added/updated host entry '$ENTRY_IP $ENTRY_NAME'"
    fi
fi
