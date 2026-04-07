#!/bin/bash
set -e

MANAGER_IP=$1

if [ -z "$MANAGER_IP" ]; then
    echo "Error: Manager IP address not provided"
    exit 1
fi

echo "========================================="
echo "Initializing Docker Swarm Manager..."
echo "========================================="

# Initialize Docker Swarm
docker swarm init --advertise-addr=$MANAGER_IP

# Get the join token for workers
WORKER_JOIN_TOKEN=$(docker swarm join-token worker -q)

# Save the join command script to a shared location (Vagrant synced folder)
# This file is written out to the host, and from there taken up by the other worker machines
mkdir -p /vagrant/swarm-tokens
echo "#!/bin/bash" > /vagrant/swarm-tokens/join_worker.sh
echo "docker swarm join --token $WORKER_JOIN_TOKEN $MANAGER_IP:2377" >> /vagrant/swarm-tokens/join_worker.sh
chmod +x /vagrant/swarm-tokens/join_worker.sh

echo "Swarm Manager initialized successfully!"
echo "Manager IP: $MANAGER_IP"
echo "Worker join command saved to /vagrant/swarm-tokens/join_worker.sh"

# Display swarm status
docker node ls