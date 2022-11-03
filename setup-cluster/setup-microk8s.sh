#!/bin/bash
# NOTE: Run this with sudo

# Install microk8s on it
snap install microk8s --channel=1.24/stable --classic

# Enable CoreDNS, RBAC, hostpath-storage
#microk8s enable dns rbac hostpath-storage prometheus
microk8s enable dns rbac hostpath-storage
microk8s status --wait-ready

# Enable ubuntu user to manage microk8s
usermod -a -G microk8s ubuntu
chown -f -R ubuntu ~/.kube

# Install kubectl in microk8s-vm
snap install kubectl --classic

# Install helm in microk8s-vm
snap install helm --classic

# Install crictl in microk8s-vm
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.24.1/crictl-v1.24.1-linux-arm64.tar.gz
tar zxvf crictl-v1.24.1-linux-arm64.tar.gz -C /usr/local/bin
rm -f crictl-v1.24.1-linux-arm64.tar.gz
echo "runtime-endpoint: unix:///var/snap/microk8s/common/run/containerd.sock" > /etc/crictl.yaml

# Set up the kubeconfig
mkdir /home/ubuntu/.kube
mkdir /root/.kube
microk8s config > /home/ubuntu/.kube/config
microk8s config > /root/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Install Elasticsearch (in place of Falcosidekick UI on Mac)
#./install-elasticsearch.sh

# Install Falco
./install-falco.sh

# Set up multi-tenancy
#./setup-multitenant.sh

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