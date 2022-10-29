curl https://raw.githubusercontent.com/draios/sysdig-cloud-scripts/master/k8s_audit_config/audit-policy-v2.yaml > audit-policy.yaml
curl https://raw.githubusercontent.com/draios/sysdig-cloud-scripts/master/k8s_audit_config/webhook-config.yaml.in > webhook-config.yaml.in
multipass exec microk8s-vm -- sudo mkdir /var/snap/microk8s/common/var/lib/k8s_audit
AGENT_SERVICE_CLUSTERIP=$(kubectl get service falco-k8saudit-k8saudit-webhook -o=jsonpath={.spec.clusterIP} -n falco) envsubst < webhook-config.yaml.in > webhook-config.yaml
multipass transfer webhook-config.yaml microk8s-vm:/home/ubuntu/webhook-config.yaml
multipass exec microk8s-vm -- sudo cp /home/ubuntu/webhook-config.yaml /var/snap/microk8s/common/var/lib/k8s_audit
multipass transfer audit-policy.yaml microk8s-vm:/home/ubuntu/audit-policy.yaml
multipass exec microk8s-vm -- sudo cp /home/ubuntu/audit-policy.yaml /var/snap/microk8s/common/var/lib/k8s_audit
multipass exec microk8s-vm -- sudo cat /var/snap/microk8s/current/args/kube-apiserver >> kube-apiserver
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
multipass exec microk8s-vm -- sudo microk8s stop
multipass exec microk8s-vm -- sudo microk8s start