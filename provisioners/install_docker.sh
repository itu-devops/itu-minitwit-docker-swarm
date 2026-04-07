#!/bin/bash
set -e

echo "========================================="
echo "Installing Docker Engine..."
echo "========================================="

# Update package list
apt-get update

# Install prerequisites
apt-get install -y ca-certificates curl gnupg lsb-release openssh-server

# Add Docker GPG key
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker package repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update

# Install Docker
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Start and enable Docker and SSH
systemctl start docker
systemctl enable docker
systemctl start ssh
systemctl enable ssh

# Add vagrant user to docker group
usermod -aG docker vagrant

echo "Docker installation completed successfully!"
docker --version