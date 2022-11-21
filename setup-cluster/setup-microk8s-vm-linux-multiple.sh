#!/bin/bash

NUM_OF_VMS=1

setup_microk8s() {
    # Provision your local cluster VM
    multipass launch --cpus 2 --mem 4G --disk 20G --name microk8s-vm-$i 22.04

    # Deploy and run setup-microk8s.sh to our new VM
    multipass transfer ./bootstrap-microk8s-vm.sh microk8s-vm-$i:/home/ubuntu/
    multipass exec microk8s-vm-$i -- chmod +x /home/ubuntu/bootstrap-microk8s-vm.sh
    multipass exec microk8s-vm-$i -- /home/ubuntu/bootstrap-microk8s-vm.sh
}

for (( i=1; i<=$NUM_OF_VMS; i++))
do
    setup_microk8s > multipass-vm-$i.log &
done