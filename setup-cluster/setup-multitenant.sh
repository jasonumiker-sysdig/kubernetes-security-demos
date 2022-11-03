#!/bin/bash
# Script to create the Jane and John Users for Authentication

# Create token for Jane to access team1
JANE_TOKEN=$(openssl rand -base64 32 | base64)
echo $JANE_TOKEN > jane.token

# Create token for John to access team2
JOHN_TOKEN=$(openssl rand -base64 32 | base64)
echo $JOHN_TOKEN > john.token

# Append our new tokens to the file
echo $JANE_TOKEN",jane,jane" > ./known_tokens.csv
echo $JOHN_TOKEN",john,john" >> ./known_tokens.csv

# Add the new kubeconfig contexts for Jane and John
kubectl config set-context microk8s-jane --cluster=microk8s-cluster --namespace=team1 --user=jane
kubectl config set-context microk8s-john --cluster=microk8s-cluster --namespace=team2 --user=john
echo "- name: jane" >> ~/.kube/config
echo "  user:" >> ~/.kube/config
echo "    token: "$JANE_TOKEN >> ~/.kube/config
echo "- name: john" >> ~/.kube/config
echo "  user:" >> ~/.kube/config
echo "    token: "$JOHN_TOKEN >> ~/.kube/config

multipass transfer known_tokens.csv install_known_tokens.sh microk8s-vm:/home/ubuntu
multipass exec microk8s-vm -- chmod +x ./install_known_tokens.sh
multipass exec microk8s-vm -- sudo apt update
multipass exec microk8s-vm -- sudo apt install dos2unix -y
multipass exec microk8s-vm -- dos2unix ./install_known_tokens.sh
multipass exec microk8s-vm -- sudo ./install_known_tokens.sh