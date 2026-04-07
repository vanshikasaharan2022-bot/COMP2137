#!/bin/bash

# assignment2.sh
# COMP2137

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
info() { echo -e "${YELLOW}[INFO]${NC}  $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "=============================================="
echo "  Server Configuration Script - Assignment 2"
echo "  Host: $(hostname)  |  $(date)"
echo "=============================================="
echo ""

# Must run as root
if [[ $EUID -ne 0 ]]; then
  err "Run as root: sudo bash assignment2.sh"
  exit 1
fi


# SECTION 1: NETWORK CONFIGURATION

echo "----------------------------------------------"
echo " SECTION 1: Network Configuration"
echo "----------------------------------------------"

TARGET_IP="192.168.16.21"
TARGET_CIDR="192.168.16.21/24"

# Detect interface (safe method)
NET16_IFACE=$(ip -o addr show | awk '/192\.168\.16\./ {print $2}' | head -1)

if [[ -z "$NET16_IFACE" ]]; then
  err "Could not detect interface on 192.168.16.x network"
else
  info "Detected interface: $NET16_IFACE"

  CURRENT_IP=$(ip -o addr show "$NET16_IFACE" | awk '/inet / {print $4}' | cut -d/ -f1)

  if [[ "$CURRENT_IP" == "$TARGET_IP" ]]; then
    ok "IP already set to $TARGET_CIDR"
  else
    info "Configuring static IP: $TARGET_CIDR"

    NETPLAN_FILE=$(ls /etc/netplan/*.yaml 2>/dev/null | head -1)
    [[ -z "$NETPLAN_FILE" ]] && NETPLAN_FILE="/etc/netplan/99-assignment2.yaml"

    cp "$NETPLAN_FILE" "${NETPLAN_FILE}.bak" 2>/dev/null

    cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  ethernets:
    $NET16_IFACE:
      dhcp4: no
      addresses:
        - $TARGET_CIDR
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
EOF

    netplan apply 2>/dev/null
    ok "Static IP configured on $NET16_IFACE"
  fi
fi

# /etc/hosts (idempotent)
info "Updating /etc/hosts..."
sed -i '/server1/d' /etc/hosts
echo "$TARGET_IP server1" >> /etc/hosts
ok "/etc/hosts updated"

echo ""

# SECTION 2: SOFTWARE INSTALLATION
echo "----------------------------------------------"
echo " SECTION 2: Software Installation"
echo "----------------------------------------------"

apt-get update -qq > /dev/null 2>&1

for pkg in apache2 squid; do
  if dpkg -s "$pkg" &>/dev/null; then
    ok "$pkg already installed"
  else
    info "Installing $pkg..."
    apt-get install -y "$pkg" > /dev/null 2>&1
    ok "$pkg installed"
  fi

  if systemctl is-active --quiet "$pkg"; then
    ok "$pkg running"
  else
    systemctl enable --now "$pkg" > /dev/null 2>&1
    ok "$pkg started"
  fi
done

echo ""


# SECTION 3: USER ACCOUNTS

echo "----------------------------------------------"
echo " SECTION 3: User Accounts"
echo "----------------------------------------------"

USERS=(dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda)

DENNIS_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

for user in "${USERS[@]}"; do

  if id "$user" &>/dev/null; then
    ok "User $user exists"
  else
    useradd -m -s /bin/bash "$user"
    ok "Created user $user"
  fi

  usermod -s /bin/bash -d "/home/$user" "$user"

  HOME_DIR="/home/$user"
  SSH_DIR="$HOME_DIR/.ssh"
  AUTH_KEYS="$SSH_DIR/authorized_keys"

  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  touch "$AUTH_KEYS"
  chmod 600 "$AUTH_KEYS"

  # Generate keys as user (FIXED)
  if [[ ! -f "$SSH_DIR/id_rsa" ]]; then
    sudo -u "$user" ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/id_rsa" -N "" -q
    ok "RSA key created for $user"
  else
    ok "RSA key exists for $user"
  fi

  if [[ ! -f "$SSH_DIR/id_ed25519" ]]; then
    sudo -u "$user" ssh-keygen -t ed25519 -f "$SSH_DIR/id_ed25519" -N "" -q
    ok "ed25519 key created for $user"
  else
    ok "ed25519 key exists for $user"
  fi

  # Add keys safely (no duplicates)
  for pub in "$SSH_DIR/id_rsa.pub" "$SSH_DIR/id_ed25519.pub"; do
    if [[ -f "$pub" ]]; then
      grep -qxF "$(cat "$pub")" "$AUTH_KEYS" || cat "$pub" >> "$AUTH_KEYS"
    fi
  done

  chown -R "$user:$user" "$SSH_DIR"
done

# Dennis sudo access
if groups dennis | grep -qw sudo; then
  ok "dennis already in sudo group"
else
  usermod -aG sudo dennis
  ok "dennis added to sudo group"
fi

# Add professor key safely
if ! grep -qxF "$DENNIS_KEY" /home/dennis/.ssh/authorized_keys; then
  echo "$DENNIS_KEY" >> /home/dennis/.ssh/authorized_keys
  ok "Professor key added to dennis"
else
  ok "Professor key already exists"
fi

echo ""
echo "=============================================="
echo "  All done! $(date)"
echo "=============================================="
echo ""#!/bin/bash

# assignment2.sh
# COMP2137

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC}    $1"; }
info() { echo -e "${YELLOW}[INFO]${NC}  $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; }

echo ""
echo "=============================================="
echo "  Server Configuration Script - Assignment 2"
echo "  Host: $(hostname)  |  $(date)"
echo "=============================================="
echo ""

# Must run as root
if [[ $EUID -ne 0 ]]; then
  err "Run as root: sudo bash assignment2.sh"
  exit 1
fi


# SECTION 1: NETWORK CONFIGURATION

echo "----------------------------------------------"
echo " SECTION 1: Network Configuration"
echo "----------------------------------------------"

TARGET_IP="192.168.16.21"
TARGET_CIDR="192.168.16.21/24"

# Detect interface (safe method)
NET16_IFACE=$(ip -o addr show | awk '/192\.168\.16\./ {print $2}' | head -1)

if [[ -z "$NET16_IFACE" ]]; then
  err "Could not detect interface on 192.168.16.x network"
else
  info "Detected interface: $NET16_IFACE"

  CURRENT_IP=$(ip -o addr show "$NET16_IFACE" | awk '/inet / {print $4}' | cut -d/ -f1)

  if [[ "$CURRENT_IP" == "$TARGET_IP" ]]; then
    ok "IP already set to $TARGET_CIDR"
  else
    info "Configuring static IP: $TARGET_CIDR"

    NETPLAN_FILE=$(ls /etc/netplan/*.yaml 2>/dev/null | head -1)
    [[ -z "$NETPLAN_FILE" ]] && NETPLAN_FILE="/etc/netplan/99-assignment2.yaml"

    cp "$NETPLAN_FILE" "${NETPLAN_FILE}.bak" 2>/dev/null

    cat > "$NETPLAN_FILE" <<EOF
network:
  version: 2
  ethernets:
    $NET16_IFACE:
      dhcp4: no
      addresses:
        - $TARGET_CIDR
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]
EOF

    netplan apply 2>/dev/null
    ok "Static IP configured on $NET16_IFACE"
  fi
fi

# /etc/hosts (idempotent)
info "Updating /etc/hosts..."
sed -i '/server1/d' /etc/hosts
echo "$TARGET_IP server1" >> /etc/hosts
ok "/etc/hosts updated"

echo ""

# SECTION 2: SOFTWARE INSTALLATION
echo "----------------------------------------------"
echo " SECTION 2: Software Installation"
echo "----------------------------------------------"

apt-get update -qq > /dev/null 2>&1

for pkg in apache2 squid; do
  if dpkg -s "$pkg" &>/dev/null; then
    ok "$pkg already installed"
  else
    info "Installing $pkg..."
    apt-get install -y "$pkg" > /dev/null 2>&1
    ok "$pkg installed"
  fi

  if systemctl is-active --quiet "$pkg"; then
    ok "$pkg running"
  else
    systemctl enable --now "$pkg" > /dev/null 2>&1
    ok "$pkg started"
  fi
done

echo ""


# SECTION 3: USER ACCOUNTS

echo "----------------------------------------------"
echo " SECTION 3: User Accounts"
echo "----------------------------------------------"

USERS=(dennis aubrey captain snibbles brownie scooter sandy perrier cindy tiger yoda)

DENNIS_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG4rT3vTt99Ox5kndS4HmgTrKBT8SKzhK4rhGkEVGlCI student@generic-vm"

for user in "${USERS[@]}"; do

  if id "$user" &>/dev/null; then
    ok "User $user exists"
  else
    useradd -m -s /bin/bash "$user"
    ok "Created user $user"
  fi

  usermod -s /bin/bash -d "/home/$user" "$user"

  HOME_DIR="/home/$user"
  SSH_DIR="$HOME_DIR/.ssh"
  AUTH_KEYS="$SSH_DIR/authorized_keys"

  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  touch "$AUTH_KEYS"
  chmod 600 "$AUTH_KEYS"

  # Generate keys as user (FIXED)
  if [[ ! -f "$SSH_DIR/id_rsa" ]]; then
    sudo -u "$user" ssh-keygen -t rsa -b 4096 -f "$SSH_DIR/id_rsa" -N "" -q
    ok "RSA key created for $user"
  else
    ok "RSA key exists for $user"
  fi

  if [[ ! -f "$SSH_DIR/id_ed25519" ]]; then
    sudo -u "$user" ssh-keygen -t ed25519 -f "$SSH_DIR/id_ed25519" -N "" -q
    ok "ed25519 key created for $user"
  else
    ok "ed25519 key exists for $user"
  fi

  # Add keys safely (no duplicates)
  for pub in "$SSH_DIR/id_rsa.pub" "$SSH_DIR/id_ed25519.pub"; do
    if [[ -f "$pub" ]]; then
      grep -qxF "$(cat "$pub")" "$AUTH_KEYS" || cat "$pub" >> "$AUTH_KEYS"
    fi
  done

  chown -R "$user:$user" "$SSH_DIR"
done

# Dennis sudo access
if groups dennis | grep -qw sudo; then
  ok "dennis already in sudo group"
else
  usermod -aG sudo dennis
  ok "dennis added to sudo group"
fi

# Add professor key safely
if ! grep -qxF "$DENNIS_KEY" /home/dennis/.ssh/authorized_keys; then
  echo "$DENNIS_KEY" >> /home/dennis/.ssh/authorized_keys
  ok "Professor key added to dennis"
else
  ok "Professor key already exists"
fi

echo ""
echo "=============================================="
echo "  All done! $(date)"
echo "=============================================="
echo ""
