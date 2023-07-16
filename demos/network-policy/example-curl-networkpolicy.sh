#!/bin/bash
# Script to curl hello-server from security-playground

NODE_IP=$(kubectl get nodes -o wide | awk 'FNR == 2 {print $6}')
NODE_PORT=30000

echo "Curling hello-server in team1 Namespace from security-playground in team2"
curl -X POST $NODE_IP:$NODE_PORT/exec -d 'command=curl http://hello-server.team1.svc:8080'
