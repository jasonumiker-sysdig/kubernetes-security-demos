#!/bin/bash

# You can reset things back to defaults by deleting the VM and then let the script recreate
multipass delete microk8s-vm
multipass purge

# Provision your local cluster VM
multipass launch --cpus 2 --mem 4G --disk 20G --name microk8s-vm 22.04

# Deploy and run setup-microk8s.sh to our new VM
multipass transfer ./bootstrap-microk8s-vm.sh microk8s-vm:/home/ubuntu/
multipass exec microk8s-vm -- sudo apt update -y
multipass exec microk8s-vm -- sudo apt install dos2unix -y
multipass exec microk8s-vm -- dos2unix //home/ubuntu/bootstrap-microk8s-vm.sh
multipass exec microk8s-vm -- chmod +x //home/ubuntu/bootstrap-microk8s-vm.sh
multipass exec microk8s-vm -- //home/ubuntu/bootstrap-microk8s-vm.sh

# Copy the .kube/config to the local machine
multipass transfer microk8s-vm:/home/ubuntu/.kube/config ~/.kube/config