helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm install -n gatekeeper-system gatekeeper gatekeeper/gatekeeper --create-namespace
kubectl apply -k ./policies/constraint-templates
sleep 5
kubectl apply -k ./policies/constraints
