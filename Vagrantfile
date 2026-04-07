# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "bento/ubuntu-22.04"

  # Define the number of swarm nodes
  MANAGER_COUNT = 1
  WORKER_COUNT = 2
  BASE_IP = "192.168.20"
  IP_START = 6

  # Manager nodes
  (1..MANAGER_COUNT).each do |i|
    config.vm.define "swarm-manager-#{i}" do |manager|
      manager.vm.hostname = "swarm-manager-#{i}"
      manager.vm.network "private_network", ip: "#{BASE_IP}.#{IP_START + i - 1}"

      manager.vm.provider "virtualbox" do |vb|
        vb.memory = 2048
        vb.cpus = 2
        vb.name = "swarm-manager-#{i}"
      end

      # Provision with Docker and initialize swarm
      manager.vm.provision "shell", path: "provisioners/install_docker.sh"
      manager.vm.provision "shell", path: "provisioners/configure_firewall_manager.sh"
      manager.vm.provision "shell", path: "provisioners/init_swarm_manager.sh", args: "#{BASE_IP}.#{IP_START + i - 1}"
      manager.vm.provision "shell", path: "provisioners/build_app_image.sh"
    end
  end

  # Worker nodes
  (1..WORKER_COUNT).each do |i|
    config.vm.define "swarm-worker-#{i}" do |worker|
      worker.vm.hostname = "swarm-worker-#{i}"
      worker.vm.network "private_network", ip: "#{BASE_IP}.#{IP_START + MANAGER_COUNT + i - 1}"

      worker.vm.provider "virtualbox" do |vb|
        vb.memory = 2048
        vb.cpus = 2
        vb.name = "swarm-worker-#{i}"
      end

      # Provision with Docker
      worker.vm.provision "shell", path: "provisioners/install_docker.sh"
      worker.vm.provision "shell", path: "provisioners/configure_firewall_worker.sh"
      worker.vm.provision "shell", path: "provisioners/join_swarm_worker.sh"
    end
  end
end