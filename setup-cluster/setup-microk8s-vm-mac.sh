#!/bin/bash

# You can reset things back to defaults by deleting the VM and then let the script recreate
multipass delete microk8s-vm
multipass purge

# Provision your local cluster VM
multipass launch --cpus 6 --mem 16G --disk 50G --name microk8s-vm 22.04

# Install microk8s on it
multipass exec microk8s-vm -- sudo snap install microk8s --channel=1.24/stable --classic

# Enable CoreDNS, RBAC, hostpath-storage and Prometheus
multipass exec microk8s-vm -- sudo microk8s enable dns rbac hostpath-storage prometheus
multipass exec microk8s-vm -- sudo microk8s status --wait-ready

# Enable ubuntu user to manage microk8s
multipass exec microk8s-vm -- sudo usermod -a -G microk8s ubuntu
multipass exec microk8s-vm -- sudo chown -f -R ubuntu ~/.kube

# Install kubectl in microk8s-vm
multipass exec microk8s-vm -- sudo snap install kubectl --classic

# Install helm in microk8s-vm
multipass exec microk8s-vm -- sudo snap install helm --classic

# Install crictl in microk8s-vm
multipass exec microk8s-vm -- wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.24.1/crictl-v1.24.1-linux-arm64.tar.gz
multipass exec microk8s-vm -- sudo tar zxvf crictl-v1.24.1-linux-arm64.tar.gz -C /usr/local/bin
multipass exec microk8s-vm -- rm -f crictl-v1.24.1-linux-arm64.tar.gz
multipass transfer install_crictl_conf.sh microk8s-vm:/home/ubuntu
multipass exec microk8s-vm -- chmod +x ./install_crictl_conf.sh
multipass exec microk8s-vm -- sudo ./install_crictl_conf.sh

# Set up the kubeconfig
microk8s config > ~/.kube/config

# Install Elasticsearch
./install-elasticsearch.sh

# Install Falco
./install-falco.sh

# Set up multi-tenancy
./setup-multitenant.sh

# Enable auditing
#curl https://raw.githubusercontent.com/draios/sysdig-cloud-scripts/master/k8s_audit_config/audit-policy-v2.yaml > audit-policy.yaml
#curl https://raw.githubusercontent.com/draios/sysdig-cloud-scripts/master/k8s_audit_config/webhook-config.yaml.in > webhook-config.yaml.in
multipass exec microk8s-vm -- sudo mkdir /var/snap/microk8s/common/var/lib/k8s_audit
AGENT_SERVICE_CLUSTERIP=$(kubectl get service falco-k8saudit-k8saudit-webhook -o=jsonpath={.spec.clusterIP} -n falco) envsubst < webhook-config.yaml.in > webhook-config.yaml
multipass transfer webhook-config.yaml microk8s-vm:/home/ubuntu/webhook-config.yaml
multipass exec microk8s-vm -- sudo cp /home/ubuntu/webhook-config.yaml /var/snap/microk8s/common/var/lib/k8s_audit
multipass transfer audit-policy.yaml microk8s-vm:/home/ubuntu/audit-policy.yaml
multipass exec microk8s-vm -- sudo cp /home/ubuntu/audit-policy.yaml /var/snap/microk8s/common/var/lib/k8s_audit
multipass exec microk8s-vm -- sudo cat /var/snap/microk8s/current/args/kube-apiserver > kube-apiserver
cat << EOF >> kube-apiserver
--audit-log-path=/var/snap/microk8s/common/var/lib/k8s_audit/k8s_audit_events.log
--audit-policy-file=/var/snap/microk8s/common/var/lib/k8s_audit/audit-policy.yaml
--audit-log-maxbackup=1
--audit-log-maxsize=10
--audit-webhook-config-file=/var/snap/microk8s/common/var/lib/k8s_audit/webhook-config.yaml
--audit-webhook-batch-max-wait=5s
EOF
multipass transfer kube-apiserver microk8s-vm:/home/ubuntu/kube-apiserver
multipass exec microk8s-vm -- sudo mv /var/snap/microk8s/current/args/kube-apiserver /var/snap/microk8s/current/args/kube-apiserver-orig
multipass exec microk8s-vm -- sudo cp /home/ubuntu/kube-apiserver /var/snap/microk8s/current/args/
multipass exec microk8s-vm -- sudo chown root:microk8s /var/snap/microk8s/current/args/kube-apiserver
multipass exec microk8s-vm -- sudo microk8s stop
multipass exec microk8s-vm -- sudo microk8s start