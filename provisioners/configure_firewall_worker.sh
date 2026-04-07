#!/bin/bash
set -e

echo "========================================="
echo "Configuring Worker Firewall..."
echo "========================================="

ufw allow 22/tcp
ufw allow 7946/tcp
ufw allow 7946/udp
ufw allow 4789/udp
ufw allow 5001/tcp
ufw reload
ufw --force enable
systemctl restart docker