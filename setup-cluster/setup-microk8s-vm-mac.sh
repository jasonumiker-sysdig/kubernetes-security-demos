#!/bin/bash

# You can reset things back to defaults by deleting the VM and then let the script recreate
multipass delete microk8s-vm
multipass purge

# Provision your local cluster VM
multipass launch --cpus 4 --mem 16G --disk 50G --name microk8s-vm 22.04

# Install microk8s on it
multipass exec microk8s-vm -- sudo snap install microk8s --channel=1.24/stable --classic

# Enable CoreDNS, RBAC and hostpath-storage
multipass exec microk8s-vm -- sudo microk8s enable dns rbac hostpath-storage
multipass exec microk8s-vm -- sudo microk8s status --wait-ready

# Enable ubuntu user to manage microk8s
multipass exec microk8s-vm -- sudo usermod -a -G microk8s ubuntu
multipass exec microk8s-vm -- sudo chown -f -R ubuntu ~/.kube

# Install kubectl in microk8s-vm
multipass exec microk8s-vm -- sudo snap install kubectl --classic

# Install crictl in microk8s-vm
multipass exec microk8s-vm -- wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.24.1/crictl-v1.24.1-linux-arm64.tar.gz
multipass exec microk8s-vm -- sudo tar zxvf crictl-v1.24.1-linux-arm64.tar.gz -C /usr/local/bin
multipass exec microk8s-vm -- rm -f crictl-v1.24.1-linux-arm64.tar.gz
# Run the following command to point it at the non-standard containerd.sock path
#sudo echo "runtime-endpoint: unix:///var/snap/microk8s/common/run/containerd.sock" | sudo tee -a /etc/crictl.yaml

# Set up the kubeconfig
microk8s config > ~/.kube/config

# Install Elasticsearch
./install-elasticsearch.sh

# Install Falco
./install-falco.sh

# Set up multi-tenancy
./setup-multitenant.sh