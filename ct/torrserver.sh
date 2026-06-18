#!/usr/bin/env bash
# ProxmoxVE Community Script Style
# TorrServer LXC installer
# Author: Oleg Tukachev
# License: MIT

set -e

# --- Defaults ---
APP="torrserver"
CTID=${CTID:-9001}
HN=${HN:-torrserver}
DISK_SIZE=${DISK_SIZE:-4}
MEM=${MEM:-512}
CORE=${CORE:-1}
BRIDGE=${BRIDGE:-vmbr0}
NET=${NET:-dhcp}
STORAGE=${STORAGE:-local-lvm}
IMG="local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"

echo -e "\n>>> Creating LXC for $APP (CTID=$CTID)\n"

# --- Template check ---
if ! pveam list local | grep -q "debian-12"; then
    echo ">>> Downloading Debian 12 template..."
    pveam update
    pveam download local debian-12-standard_12.12-1_amd64.tar.zst
fi

IMG="local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst"


# --- Create container ---
pct create $CTID $IMG \
    -hostname $HN \
    -storage $STORAGE \
    -rootfs ${STORAGE}:${DISK_SIZE} \
    -memory $MEM \
    -cores $CORE \
    -net0 name=eth0,bridge=$BRIDGE,ip=$NET \
    -onboot 1 \
    -unprivileged 1

# --- Start container ---
pct start $CTID
sleep 5

# --- Install TorrServer ---
echo ">>> Installing TorrServer inside CT..."
pct exec $CTID -- bash -c "
  apt-get update && apt-get install -y wget curl
  mkdir -p /opt/torrserver
  cd /opt/torrserver
  wget -qO TorrServer https://github.com/YouROK/TorrServer/releases/latest/download/TorrServer-linux-amd64
  chmod +x TorrServer

  cat > /etc/systemd/system/torrserver.service <<EOF
[Unit]
Description=TorrServer
After=network.target

[Service]
Type=simple
ExecStart=/opt/torrserver/TorrServer --port 8090
Restart=on-failure
WorkingDirectory=/opt/torrserver

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload
  systemctl enable --now torrserver
"

# --- Show info ---
IP=$(pct exec $CTID ip -4 a show dev eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || true)

echo -e "\n>>> TorrServer is installed!"
echo "CTID: $CTID"
[ -n "$IP" ] && echo "Open in browser: http://$IP:8090"
