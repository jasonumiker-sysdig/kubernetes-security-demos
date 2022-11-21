#!/bin/bash

NUM_OF_VMS=1

setup_microk8s() {
    # Provision your local cluster VM
    multipass launch --cpus 2 --mem 4G --disk 20G --name microk8s-vm-$i 22.04

    # Deploy and run setup-microk8s.sh to our new VM
    multipass exec microk8s-vm-$i -- git clone https://github.com/jasonumiker-sysdig/kubernetes-opensouce-security-demos.git
    multipass exec microk8s-vm-$i -- sudo ./kubernetes-opensouce-security-demos/setup-cluster/setup-microk8s.sh
}

for (( i=1; i<=$NUM_OF_VMS; i++))
do
    setup_microk8s > multipass-vm-$i.log &
done