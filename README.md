# Minitwit on Docker Swarm

This project demonstrates Docker Swarm fundamentals with a minimal stack.

## Prerequisites

- Docker installed on your machine (for local) or
- A DigitalOcean account with SSH key uploaded

## Option A: Local Docker Swarm (Simplest)

### Step 1: Initialize Docker Swarm

```bash
docker swarm init
```

### Step 2: Build the Minitwit Image

```bash
cd docker/minitwit
docker build -t minitwitimage:latest -f Dockerfile-minitwit .
cd ../..
```

### Step 3: Deploy the stack

```bash
docker stack deploy -c minitwit_stack.yml minitwit
```

### Step 4: Access the application

- Minitwit Application: http://localhost:5001
- Visualizer: http://localhost:8888 (NOTE: Doesn't work on ARM Devices, see `minitwit_stack.yml` for potential fixes)

---

## Option B: DigitalOcean (Cloud)

This option deploys a multi-node Docker Swarm cluster on DigitalOcean using curl commands against the DigitalOcean API.

### Prerequisites

1. **DigitalOcean Account**: Sign up at https://cloud.digitalocean.com
2. **DigitalOcean Token**: Generate at https://cloud.digitalocean.com/account/api/
3. **SSH Key Uploaded**: Upload your public SSH key at https://cloud.digitalocean.com/account/security

### Step 1: Setup Environment

Copy the template and fill in your credentials:

```bash
cp env_template secrets
source secrets
```

Or set up your shell variables manually:

```bash
export DIGITAL_OCEAN_TOKEN=your_token_here
export SSH_FINGERPRINT=your_ssh_fingerprint_here
```

Then set up these environment variables.

```bash
# These are used by the API
export DROPLETS_API="https://api.digitalocean.com/v2/droplets"
export BEARER_AUTH_TOKEN="Authorization: Bearer $DIGITAL_OCEAN_TOKEN"
export JSON_CONTENT="Content-Type: application/json"
```

verify that they are correctly set

```bash
echo $DROPLETS_API # feel free to test the others.
```

### Step 2: Create the Swarm Manager

```bash
# Create the manager droplet
CONFIG='{"name":"swarm-manager","region":"fra1","size":"s-1vcpu-1gb","image":"docker-20-04","ssh_keys":["'"$SSH_FINGERPRINT"'"],"tags":["minitwit-swarm"]}'

MANAGER_ID=$(curl -X POST "$DROPLETS_API" -d "$CONFIG" \
    -H "$BEARER_AUTH_TOKEN" -H "$JSON_CONTENT" \
    | jq -r .droplet.id)

echo "Created manager droplet with ID: $MANAGER_ID"
echo "Waiting for droplet to be ready..."
sleep 120 # Can take a while

```

```bash
# Get the manager IP address
export JQFILTER='.droplets | .[] | select (.name == "swarm-manager")
    | .networks.v4 | .[]| select (.type == "public") | .ip_address'

export MANAGER_IP=$(curl -s "$DROPLETS_API" \
    -H "$BEARER_AUTH_TOKEN" -H "$JSON_CONTENT" \
    | jq -r "$JQFILTER")

echo "MANAGER_IP=$MANAGER_IP"
```

### Step 3: Create Worker Nodes

```bash
# Create Worker 1
WORKER1_ID=$(curl -X POST "$DROPLETS_API" \
    -d '{"name":"worker1","region":"fra1",
        "size":"s-1vcpu-1gb","image":"docker-20-04",
        "ssh_keys":["'"$SSH_FINGERPRINT"'"],"tags":["minitwit-swarm"]}' \
    -H "$BEARER_AUTH_TOKEN" -H "$JSON_CONTENT" \
    | jq -r .droplet.id)

echo "Created worker1 with ID: $WORKER1_ID"
sleep 5

# Create Worker 2
WORKER2_ID=$(curl -X POST "$DROPLETS_API" \
    -d '{"name":"worker2","region":"fra1",
        "size":"s-1vcpu-1gb","image":"docker-20-04",
        "ssh_keys":["'"$SSH_FINGERPRINT"'"],"tags":["minitwit-swarm"]}' \
    -H "$BEARER_AUTH_TOKEN" -H "$JSON_CONTENT" \
    | jq -r .droplet.id)

echo "Created worker2 with ID: $WORKER2_ID"
sleep 5
sleep 120 # can take a while
```

```bash
# Get Worker 1 IP
export JQFILTER='.droplets | .[] | select (.name == "worker1")
    | .networks.v4 | .[]| select (.type == "public") | .ip_address'

export WORKER1_IP=$(curl -s "$DROPLETS_API" \
    -H "$BEARER_AUTH_TOKEN" -H "$JSON_CONTENT" \
    | jq -r "$JQFILTER")

echo "WORKER1_IP=$WORKER1_IP"

# Get Worker 2 IP
export JQFILTER='.droplets | .[] | select (.name == "worker2")
    | .networks.v4 | .[]| select (.type == "public") | .ip_address'

export WORKER2_IP=$(curl -s "$DROPLETS_API" \
    -H "$BEARER_AUTH_TOKEN" -H "$JSON_CONTENT" \
    | jq -r "$JQFILTER")

echo "WORKER2_IP=$WORKER2_IP"
```

### Step 4: Configure Firewall

**Note:** The following ports are required on ALL Swarm nodes:

- 22/tcp: SSH access
- 7946/tcp+udp: Container network discovery
- 4789/udp: VXLAN overlay network (routing mesh)
- 5001/tcp: Application port

**Invariant:** Ports 2376/tcp (Docker TLS) and 2377/tcp (Swarm management) are ONLY needed on manager nodes, not on workers.

#### Configure Manager Firewall

```bash
ssh root@$MANAGER_IP "ufw allow 22/tcp && ufw allow 2376/tcp && \
ufw allow 2377/tcp && ufw allow 7946/tcp && ufw allow 7946/udp && \
ufw allow 4789/udp && ufw allow 5001/tcp && ufw reload && ufw --force enable && \
systemctl restart docker"
```

#### Configure Worker 1 Firewall

```bash
ssh root@$WORKER1_IP "ufw allow 22/tcp && ufw allow 7946/tcp && ufw allow 7946/udp && \
ufw allow 4789/udp && ufw allow 5001/tcp && ufw reload && ufw --force enable && \
systemctl restart docker"
```

#### Configure Worker 2 Firewall

```bash
ssh root@$WORKER2_IP "ufw allow 22/tcp && ufw allow 7946/tcp && ufw allow 7946/udp && \
ufw allow 4789/udp && ufw allow 5001/tcp && ufw reload && ufw --force enable && \
systemctl restart docker"
```

### Step 5: Initialize the Swarm

```bash
ssh root@$MANAGER_IP "docker swarm init --advertise-addr $MANAGER_IP"
```

Get the worker token:

```bash
WORKER_TOKEN=$(ssh root@$MANAGER_IP "docker swarm join-token worker -q")
echo "Worker token: $WORKER_TOKEN"
```

### Step 6: Join Workers to the Swarm

```bash
# Join Worker 1
ssh root@$WORKER1_IP "docker swarm join --token $WORKER_TOKEN $MANAGER_IP:2377"

# Join Worker 2
ssh root@$WORKER2_IP "docker swarm join --token $WORKER_TOKEN $MANAGER_IP:2377"
```

### Step 7: Verify the Cluster

```bash
ssh root@$MANAGER_IP "docker node ls"
```

You should see all three nodes listed.

### Step 8: Deploy the Stack

```bash
# Copy the docker directory with seed script to manager
scp -r docker/ root@$MANAGER_IP:~/

# Copy the stack file to the manager
scp minitwit_stack.yml root@$MANAGER_IP:~

# Deploy the stack
ssh root@$MANAGER_IP "docker stack deploy -c minitwit_stack.yml minitwit"
```

**Note:** For DigitalOcean deployment, you need a publicly accessible image.

**Option A - Use pre-built GHCR image (Dockerhub alternative):**
Update `stack/minitwit_stack.yml` to use:

```yaml
image: ghcr.io/itu-devops/itu-minitwit-docker-swarm/minitwitimage:latest
```

**Option B - Build and push your own (feel free to replace ghcr.io with dockerhub etc.):**

```bash
# Build with your GHCR username
docker build -t ghcr.io/YOURUSERNAME/minitwitimage:latest -f docker/minitwit/Dockerfile-minitwit .

# Login to GHCR (requires personal access token)
docker login ghcr.io -u YOURUSERNAME

# Push
docker push ghcr.io/YOURUSERNAME/minitwitimage:latest

# Update stack file with your image
```

Then copy and deploy the stack.

### Step 9: Verify Deployment

```bash
# Check services
ssh root@$MANAGER_IP "docker service ls"

# Check stack status
ssh root@$MANAGER_IP "docker stack ps minitwit"
```

### Access the Application

- Minitwit Application: http://$MANAGER_IP:5001
- Visualizer: http://$MANAGER_IP:8888

---

## Docker Stack Explanation

The `minitwit_stack.yml` file defines the services:

| Service       | Image                    | Description                                              |
| ------------- | ------------------------ | -------------------------------------------------------- |
| `visualizer`  | dockersamples/visualizer | Web UI showing swarm cluster state                       |
| `minitwit`    | minitwitimage:latest     | Minitwit application (5 replicas)                        |
| `itusqlimage` | mariadb:10.6             | MariaDB database (MySQL compatible) with minitwit schema |

---

## Docker Swarm Cluster Roles

Nodes in a Docker Swarm have these roles:

- **Leader**: Primary manager that performs orchestration
- **Manager**: Can manage the cluster; commands are forwarded to the leader
- **Worker**: Runs containers

**Important**: In Docker Swarm, the leader is also a manager, and all managers are also workers by default.

---

## Useful Commands

```bash
# List all nodes
docker node ls

# List containers on each node
for node in $(docker node ls -q); do docker node ps $node; done

# List all services
docker service ls

# List containers in a service
docker service ps <service-name>

# Scale a service manually
docker service scale minitwit_minitwit=10

# Force recreate all containers (redistribute across cluster)
for service in $(docker service ls -q); do docker service update --force $service; done

# Rolling update of a service
docker service update --image minitwitimage:latest <service-name>

# Rollback last update
docker service rollback <service-name>

# Remove the stack
docker stack rm minitwit

# Leave the swarm (on worker nodes)
docker swarm leave

# Leave the swarm as manager (on manager node)
docker swarm leave --force
```

---

## Cleaning Up (DigitalOcean)

To delete all droplets:

```bash
curl -X DELETE \
    -H "$BEARER_AUTH_TOKEN" -H "$JSON_CONTENT" \
    "https://api.digitalocean.com/v2/droplets?tag_name=minitwit-swarm"
```

Or delete individual droplets:

```bash
curl -X DELETE \
    -H "$BEARER_AUTH_TOKEN" -H "$JSON_CONTENT" \
    "https://api.digitalocean.com/v2/droplets/$MANAGER_ID"
```
