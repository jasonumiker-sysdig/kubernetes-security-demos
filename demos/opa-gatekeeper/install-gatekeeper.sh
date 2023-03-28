helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install -n gatekeeper-system gatekeeper gatekeeper/gatekeeper --create-namespace --set replicas=1
kubectl wait deployment -n gatekeeper-system gatekeeper-controller-manager --for condition=Available=True --timeout=90s
kubectl apply -k ./policies/constraint-templates
sleep 10
kubectl apply -k ./policies/constraints
