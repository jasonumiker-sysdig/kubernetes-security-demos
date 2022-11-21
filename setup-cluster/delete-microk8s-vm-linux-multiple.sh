#!/bin/bash

NUM_OF_VMS=15

for (( i=1; i<=$NUM_OF_VMS; i++))
do
    multipass stop microk8s-vm-$i
    multipass delete microk8s-vm-$i
done
multipass purge