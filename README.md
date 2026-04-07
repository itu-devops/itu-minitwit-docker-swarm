# _ITU-MiniTwit_ on Docker Swarm

This project demonstrates Docker Swarm fundamentals with a minimal _ITU-MiniTwit_ stack deployed to a Docker Swarm cluster consisting of local virtual machines.


## Bring up the Swarm

This Docker Swarm cluster consists of one manager node and two worker nodes, see default configuration in [Vagrantfile](./Vagrantfile).
Each node is configured with 2 CPUs and 2048 MB of RAM.
The manager node has the IP address 192.168.20.6.
The worker nodes are assigned IP addresses 192.168.20.7 and 192.168.20.8 respectively.



To bring up this Docker Swarm cluster run:

```bash
vagrant up
```

Note, since this creates and configures multiple virtual machines, this will take some time.
While the cluster is created, familiarize yourself with the [provisioner scripts](./provisioners).


## Deploy the Application Stack

On the swarm manager node, execute the following command>

```bash
docker stack deploy -c minitwit_stack.yml minitwit
```

You can execute commands directly on the nodes via SSH as in the following.
If in doubt, read the respective help `vagrant ssh --help`.

```bash
vagrant ssh swarm-manager-1 -c  "docker stack deploy -c minitwit_stack.yml minitwit"
```

### Access the Application

- Minitwit Application: http://192.168.20.6:5001
- Visualizer: http://192.168.20.6:8888

Note, per default the visualizer container image, is currently not supported on ARM devices like Apple MacBooks.
If required, you might [build your own image supporting your architecture](https://github.com/dockersamples/docker-swarm-visualizer#building-a-custom-image).

---

## Docker Stack Explanation

The [`minitwit_stack.yml`](./minitwit_stack.yml) file defines the services:

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

vagrant ssh swarm-manager-1 -c "docker stack deploy -c /vagrant/minitwit_stack.yml minitwit"

# List all nodes
vagrant ssh swarm-manager-1 -c "docker node ls"

# List containers on each node
vagrant ssh swarm-manager-1 -c 'for node in $(docker node ls -q); do docker node ps $node; done'

# List all services
vagrant ssh swarm-manager-1 -c "docker service ls"

# List containers in a service
vagrant ssh swarm-manager-1 -c "docker service ps <service-name>"

# Scale a service manually
vagrant ssh swarm-manager-1 -c "docker service scale minitwit_minitwit=10"

# Force recreate all containers (redistribute across cluster)
vagrant ssh swarm-manager-1 -c "for service in $(docker service ls -q); do docker service update --force $service; done"

# Rolling update of a service
vagrant ssh swarm-manager-1 -c "docker service update --image minitwitimage:latest <service-name>"

# Rollback last update
vagrant ssh swarm-manager-1 -c "docker service rollback <service-name>"

# Remove the stack
vagrant ssh swarm-manager-1 -c "docker stack rm minitwit"

# Leave the swarm (on worker nodes)
vagrant ssh swarm-manager-1 -c "docker swarm leave"

# Leave the swarm as manager (on manager node)
vagrant ssh swarm-manager-1 -c "docker swarm leave --force"
```

---

## Task 1: Deployment and Scaling of the Application

Deploy the application to the Docker Swarm cluster.
Per default, this creates two instances (called _replicas_) of the _ITU-MiniTwit_ application on the cluster

```bash
vagrant ssh swarm-manager-1 -c "docker stack deploy -c /vagrant/minitwit_stack.yml minitwit"
```

With your browser, navigate to the Docker Swarm visualizer tool and verify that you have two replicas of the _ITU-MiniTwit_ application running on the cluster as well as one instance of the database container and visualizer container (both on the manager node).

```bash
open http://192.168.20.6:8888
```

Now, scale up the _ITU-MiniTwit_ application to ten instances:

```bash
vagrant ssh swarm-manager-1 -c "docker service scale minitwit_minitwit=10"
```

Double check in the visualizer that you have the respective amount of containers distributed over the network.

Thereafter, scale down the _ITU-MiniTwit_ application to five instances:

```bash
vagrant ssh swarm-manager-1 -c "docker service scale minitwit_minitwit=5"
```

Now, check directly on each node which container is running:

```bash
vagrant ssh swarm-manager-1 -c 'for node in $(docker node ls -q); do docker node ps $node; done'
```


## Task 2: Scaling of the Docker Swarm Cluster

Manually, create yet another worker node and make it join the Docker Swarm cluster.
First, change line 9 in the Vagrantfile from `WORKER_COUNT = 2` to `WORKER_COUNT = 3`.
Now, create a new node for the cluster.

```bash
vagrant up swarm-worker-3
```

Check in the visualizer, that you have now three worker nodes in the cluster.

How does the worker node join the swarm?
Inspect the [`join_swarm_worker.sh`](./provisioners/join_swarm_worker.sh) script.
It calls the script `/vagrant/swarm-tokens/join_worker.sh`, which is generated automatically during provisioning of the manager node.
You can find this script on your local host at [`/vagrant/swarm-tokens/join_worker.sh`](./swarm-tokens/join_worker.sh)

To experiment with how nodes join a Docker Swarm cluster, first let the newly created node leave the cluster:

```bash
vagrant ssh swarm-worker-3 -c "docker swarm leave"
```

Double check in the visualizer, that you have now only two worker nodes in the cluster.

On your host, inspect the contents of the [`join_worker.sh`](./swarm-tokens/join_worker.sh) script, which each worker node executes automatically during provisioning.
Now, on the newly created worker node `swarm-worker-3`, execute that script to join the swarm again:

```bash
vagrant ssh swarm-worker-3 -c "bash /vagrant/swarm-tokens/join_worker.sh"
```

Double check in the visualizer, that you have now three worker nodes in the cluster again.

---

## Cleaning Up

To destroy all nodes of the local Docker Swarm cluster, run:

```bash
vagrant destroy
```

Delete the script containing the join token of the not existing manager node:

```bash
rm ./swarm-tokens/join_worker.sh
```