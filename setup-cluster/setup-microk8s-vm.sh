#!/bin/bash

# You can reset things back to defaults by deleting the VM and then let the script recreate
multipass delete microk8s-vm --purge

# Provision your local cluster VM
multipass launch --cpus 2 --memory 4G --disk 10G --name microk8s-vm --cloud-init cloud-init.yaml --timeout 600 22.04

# Copy the .kube/config to the local machine
#cd ~/.kube
#multipass transfer microk8s-vm:/home/ubuntu/.kube/config config