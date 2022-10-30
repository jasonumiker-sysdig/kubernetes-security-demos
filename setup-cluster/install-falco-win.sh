helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco --namespace falco --create-namespace --set driver.kind=ebpf --set collectors.containerd.socket="//var/snap/microk8s/common/run/containerd.sock" --set falco.json_output=true --set falcosidekick.enabled=true --set falcosidekick.webui.enabled=true --set tty=true
helm install falco-k8saudit falcosecurity/falco --namespace falco --create-namespace -f falco-k8saudit-values-win.yaml