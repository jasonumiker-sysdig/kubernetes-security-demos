#!/bin/bash
# This script will run through all the demos to both test that they work as
# well as to trigger all of the associated Events in Falco

# Wait for falco agent to be up before proceeding
kubectl rollout status daemonset falco -n falco --timeout 300s

echo "Demo of Kubernetes Role-based Access Control (RBAC) and Namespaces"
echo "--------------------"
kubectl config use-context microk8s
kubectl get pods -A
echo "--------------------"
kubectl api-resources
echo "--------------------"
kubectl get clusterrole admin -o yaml
echo "--------------------"
kubectl get clusterrole admin -o yaml | wc -l
echo "--------------------"
cd ~/kubernetes-security-demos
cat team1.yaml
echo "--------------------"
kubectl apply -f team1.yaml && kubectl apply -f team2.yaml
echo "--------------------"
kubectl config get-contexts
echo "--------------------"
kubectl config use-context microk8s-jane
echo "--------------------"
kubectl get pods -A
echo "--------------------"
kubectl get pods
echo "--------------------"
cd ~/kubernetes-security-demos/demos/network-policy/hello-app
echo "--------------------"
kubectl apply -f .
echo "--------------------"
kubectl get pods
echo "--------------------"
kubectl describe deployments hello-client-allowed
echo "--------------------"
kubectl exec -it deploy/hello-client-allowed -n team1 -- /bin/sh -c whoami
echo "--------------------"
kubectl apply -f ../../../team1-noexec.yaml
echo "--------------------"
kubectl exec -it deploy/hello-client-allowed -n team1 -- /bin/sh
echo "--------------------"
kubectl config use-context microk8s-john
echo "--------------------"
kubectl get pods
echo "--------------------"
kubectl get pods --namespace=team1
echo "--------------------"

echo ""
echo "Demo of common runtime container exploits/escapes"
echo "--------------------"
kubectl config get-contexts
echo "--------------------"
cd ~/kubernetes-security-demos/demos/security-playground/
kubectl apply -f security-playground.yaml
kubectl rollout status deployment security-playground --timeout 300s
kubectl rollout status deployment postgres-sakila --timeout 300s
echo "--------------------"
kubectl get all
echo "--------------------"
kubectl config use-context microk8s
echo "--------------------"
./example-curls.sh
echo "--------------------"
cd ~/kubernetes-security-demos/demos/security-playground
cat security-playground-restricted.yaml
echo "--------------------"
kubectl apply -f security-playground-restricted.yaml
kubectl rollout status deployment security-playground-restricted --timeout 300s -n security-playground-restricted
echo "--------------------"
./example-curls-restricted.sh
echo "--------------------"
kubectl describe namespace security-playground-restricted
echo "--------------------"
kubectl apply -f security-playground.yaml -n security-playground-restricted
kubectl delete -f security-playground.yaml -n security-playground-restricted
echo "--------------------"
cd ~/kubernetes-security-demos/demos
kubectl apply -f kubebench-job.yaml
kubectl wait job/kube-bench --for condition=complete
echo "--------------------"
kubectl logs job/kube-bench
echo "--------------------"

echo ""
echo "Demo of common runtime container exploits/escapes"
echo "--------------------"
kubectl logs deployment/hello-client-allowed -n team1
echo "--------------------"
kubectl logs deployment/hello-client-blocked -n team1
echo "--------------------"
cd ~/kubernetes-security-demos/demos/network-policy
cat example-curl-networkpolicy.sh
echo "--------------------"
./example-curl-networkpolicy.sh
echo "--------------------"
cat network-policy-namespace.yaml
echo "--------------------"
kubectl apply -f network-policy-namespace.yaml
echo "--------------------"
kubectl logs deployment/hello-client-allowed -n team1
echo "--------------------"
kubectl logs deployment/hello-client-blocked -n team1
echo "--------------------"
./example-curl-networkpolicy.sh
echo "--------------------"
cat network-policy-label.yaml
echo "--------------------"
kubectl apply -f network-policy-label.yaml
echo "--------------------"
kubectl logs deployment/hello-client-blocked -n team1
echo "--------------------"
./example-curl-networkpolicy.sh
echo "--------------------"
cat network-policy-deny-egress.yaml
echo "--------------------"
kubectl apply -f network-policy-deny-egress.yaml -n security-playground-restricted
echo "--------------------"
kubectl delete --all pods --namespace=security-playground-restricted
kubectl rollout status deployment security-playground --timeout 300s -n security-playground-restricted
echo "--------------------"
../security-playground/example-curls-restricted.sh
echo "--------------------"
echo "The End."