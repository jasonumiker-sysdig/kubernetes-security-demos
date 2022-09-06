kubectl delete -k ./policies/constraints
kubectl delete -k ./policies/constraint-templates
helm uninstall gatekeeper -n gatekeeper-system
