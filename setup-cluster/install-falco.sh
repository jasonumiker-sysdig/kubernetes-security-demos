helm repo add falcosecurity https://falcosecurity.github.io/charts
helm repo update
helm install falco falcosecurity/falco --namespace falco --create-namespace --set driver.kind=ebpf --set collectors.containerd.socket="/var/snap/microk8s/common/run/containerd.sock" --set falco.json_output=true
kubectl patch daemonset falco --patch '{"spec":{"template":{"spec":{"$setElementOrder/containers":[{"name":"falco"}],"containers":[{"name":"falco","tty":true}]}}}}'
