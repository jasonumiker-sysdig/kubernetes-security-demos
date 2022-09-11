helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts
helm repo update
helm install -n gatekeeper-system gatekeeper gatekeeper/gatekeeper --create-namespace
kubectl apply -k ./policies/constraint-templates
sleep 10
kubectl apply -k ./policies/constraints
