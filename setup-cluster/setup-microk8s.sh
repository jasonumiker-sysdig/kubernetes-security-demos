#!/bin/bash
# NOTE: Run this with sudo inside microk8s-vm

# Install microk8s
snap install microk8s --channel=1.29/stable --classic

# Enable CoreDNS, RBAC, hostpath-storage, ingress
microk8s enable dns 
microk8s enable hostpath-storage
microk8s enable rbac
#microk8s enable observability
microk8s enable community
microk8s enable trivy
microk8s enable falco
microk8s status --wait-ready

# Install kubectl in microk8s-vm
snap install kubectl --channel 1.29/stable --classic

# Install helm in microk8s-vm
snap install helm --classic

# Install crictl in microk8s-vm
# Now installing this through example-curls.sh instead
#ARCH=$(dpkg --print-architecture)
#wget -q https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.27.1/crictl-v1.27.1-linux-$ARCH.tar.gz
#tar zxvf crictl-v1.27.1-linux-$ARCH.tar.gz -C /usr/local/bin
#rm -f crictl-v1.27.1-linux-$ARCH.tar.gz
echo "runtime-endpoint: unix:///var/snap/microk8s/common/run/containerd.sock" > /etc/crictl.yaml

# Set up the kubeconfig
#mkdir /root/.kube
microk8s.config | cat - > /root/.kube/config

# Install Falco
#helm repo add falcosecurity https://falcosecurity.github.io/charts
#helm repo update
#helm install falco falcosecurity/falco --namespace falco --create-namespace -f falco-values.yaml --version 3.7.1 --kubeconfig /root/.kube/config

# Set up multi-tenancy
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
kubectl config set-context microk8s-jane --cluster=microk8s-cluster --namespace=team1 --user=jane --kubeconfig=/root/.kube/config
kubectl config set-context microk8s-john --cluster=microk8s-cluster --namespace=team2 --user=john --kubeconfig=/root/.kube/config
echo "- name: jane" >> /root/.kube/config
echo "  user:" >> /root/.kube/config
echo "    token: "$JANE_TOKEN >> /root/.kube/config
echo "- name: john" >> /root/.kube/config
echo "  user:" >> /root/.kube/config
echo "    token: "$JOHN_TOKEN >> /root/.kube/config
cat known_tokens.csv >> /var/snap/microk8s/current/credentials/known_tokens.csv
microk8s stop
microk8s start
mkdir /home/ubuntu/.kube/
cp /root/.kube/config /home/ubuntu/.kube/config
chown ubuntu:ubuntu -R /home/ubuntu/.kube

# Enable auditing
#mkdir /var/snap/microk8s/common/var/lib/k8s_audit
#AGENT_SERVICE_CLUSTERIP=$(kubectl get service falco-k8saudit-webhook -o=jsonpath={.spec.clusterIP} -n falco) envsubst < webhook-config.yaml.in > webhook-config.yaml
#cp ./webhook-config.yaml /var/snap/microk8s/common/var/lib/k8s_audit
#cp ./audit-policy.yaml /var/snap/microk8s/common/var/lib/k8s_audit
#cat /var/snap/microk8s/current/args/kube-apiserver > kube-apiserver
#cat << EOF >> kube-apiserver
#--audit-log-path=/var/snap/microk8s/common/var/lib/k8s_audit/k8s_audit_events.log
#--audit-policy-file=/var/snap/microk8s/common/var/lib/k8s_audit/audit-policy.yaml
#--audit-log-maxbackup=1
#--audit-log-maxsize=10
#--audit-webhook-config-file=/var/snap/microk8s/common/var/lib/k8s_audit/webhook-config.yaml
#--audit-webhook-batch-max-wait=5s
#EOF
#mv /var/snap/microk8s/current/args/kube-apiserver /var/snap/microk8s/current/args/kube-apiserver-orig
#cp ./kube-apiserver /var/snap/microk8s/current/args/
#chown root:microk8s /var/snap/microk8s/current/args/kube-apiserver
#microk8s stop
#microk8s start
#sleep 30
#kubectl rollout status daemonset falco -n falco --timeout 300s