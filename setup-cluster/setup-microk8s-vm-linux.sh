#!/bin/bash

# You can reset things back to defaults by deleting the VM and then let the script recreate
multipass delete microk8s-vm
multipass purge

# Provision your local cluster VM
multipass launch --cpus 2 --mem 4G --disk 20G --name microk8s-vm 22.04

# Deploy and run setup-microk8s.sh to our new VM
multipass exec microk8s-vm -- git clone https://github.com/jasonumiker-sysdig/kubernetes-opensouce-security-demos.git
multipass exec microk8s-vm -- sudo ./kubernetes-opensouce-security-demos/setup-cluster/setup-microk8s.sh

# Copy the .kube/config to the local machine
multipass transfer microk8s-vm:/home/ubuntu/.kube/config ~/.kube/config