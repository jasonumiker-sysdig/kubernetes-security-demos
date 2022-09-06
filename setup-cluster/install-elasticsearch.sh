helm repo add elastic https://helm.elastic.co
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update
helm install elasticsearch elastic/elasticsearch -n monitoring --create-namespace --set replicas=1 
helm install fluent-bit fluent/fluent-bit -n monitoring
helm install kibana elastic/kibana -n monitoring