sudo microk8s helm repo add grafana https://grafana.github.io/helm-charts
sudo microk8s helm repo update
sudo microk8s helm install grafana grafana/grafana
