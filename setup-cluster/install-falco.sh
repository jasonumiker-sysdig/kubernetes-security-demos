helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco --namespace falco --create-namespace -f falco-values.yaml --kubeconfig /root/.kube/config
helm install falco-k8saudit falcosecurity/falco --namespace falco --create-namespace -f falco-k8saudit-values-win.yaml --kubeconfig /root/.kube/config