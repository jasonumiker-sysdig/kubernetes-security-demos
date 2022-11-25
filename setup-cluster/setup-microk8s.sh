#!/bin/bash
# NOTE: Run this with sudo

# Install microk8s on it
snap install microk8s --channel=1.24/stable --classic

# Enable CoreDNS, RBAC, hostpath-storage, ingress
microk8s enable dns rbac hostpath-storage ingress
microk8s status --wait-ready

# Install kubectl in microk8s-vm
snap install kubectl --classic

# Install helm in microk8s-vm
snap install helm --classic

# Install crictl in microk8s-vm
wget -q https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.24.1/crictl-v1.24.1-linux-amd64.tar.gz
tar zxvf crictl-v1.24.1-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-v1.24.1-linux-amd64.tar.gz
echo "runtime-endpoint: unix:///var/snap/microk8s/common/run/containerd.sock" > /etc/crictl.yaml

# Set up the kubeconfig
mkdir /root/.kube
microk8s.config | cat - > /root/.kube/config

# Install Falco
helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco --namespace falco --create-namespace -f falco-values.yaml
helm install falco-k8saudit falcosecurity/falco --namespace falco --create-namespace -f falco-k8saudit-values.yaml 

# Install Elasticsearch (as alternative for FalcosidekickUI)
#helm repo add elastic https://helm.elastic.co
#helm repo add fluent https://fluent.github.io/helm-charts
#helm repo update
#helm install elasticsearch elastic/elasticsearch -n monitoring --create-namespace -f elastic-values.yaml
#helm install fluent-bit fluent/fluent-bit -n monitoring -f fluentbit-values.yaml
#helm install kibana elastic/kibana -n monitoring --set service.type=NodePort --set service.nodePort=30283

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
kubectl config set-context microk8s-jane --cluster=microk8s-cluster --namespace=team1 --user=jane
kubectl config set-context microk8s-john --cluster=microk8s-cluster --namespace=team2 --user=john
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
#curl https://raw.githubusercontent.com/draios/sysdig-cloud-scripts/master/k8s_audit_config/audit-policy-v2.yaml > audit-policy.yaml
#curl https://raw.githubusercontent.com/draios/sysdig-cloud-scripts/master/k8s_audit_config/webhook-config.yaml.in > webhook-config.yaml.in
mkdir /var/snap/microk8s/common/var/lib/k8s_audit
AGENT_SERVICE_CLUSTERIP=$(kubectl get service falco-k8saudit-k8saudit-webhook -o=jsonpath={.spec.clusterIP} -n falco) envsubst < webhook-config.yaml.in > webhook-config.yaml
cp ./webhook-config.yaml /var/snap/microk8s/common/var/lib/k8s_audit
cp ./audit-policy.yaml /var/snap/microk8s/common/var/lib/k8s_audit
cat /var/snap/microk8s/current/args/kube-apiserver > kube-apiserver
cat << EOF >> kube-apiserver
--audit-log-path=/var/snap/microk8s/common/var/lib/k8s_audit/k8s_audit_events.log
--audit-policy-file=/var/snap/microk8s/common/var/lib/k8s_audit/audit-policy.yaml
--audit-log-maxbackup=1
--audit-log-maxsize=10
--audit-webhook-config-file=/var/snap/microk8s/common/var/lib/k8s_audit/webhook-config.yaml
--audit-webhook-batch-max-wait=5s
EOF
mv /var/snap/microk8s/current/args/kube-apiserver /var/snap/microk8s/current/args/kube-apiserver-orig
cp ./kube-apiserver /var/snap/microk8s/current/args/
chown root:microk8s /var/snap/microk8s/current/args/kube-apiserver
microk8s stop
microk8s start