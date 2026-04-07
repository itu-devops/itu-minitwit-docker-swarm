#!/bin/bash

# Build the Docker image on the manager node
# In production, you would have built this image already in your CI pipeline, and the following
# deployment of the stack would pull it from the respective artifact store (registry).
docker build -t youruser/minitwitimage:latest /vagrant/docker/minitwit -f /vagrant/docker/minitwit/Dockerfile-minitwit
