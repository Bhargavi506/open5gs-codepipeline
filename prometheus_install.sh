#sudo microk8s helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
#sudo microk8s helm repo update
#sudo microk8s helm install prometheus prometheus-community/prometheus
sudo microk8s helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
sudo microk8s helm repo add stable https://charts.helm.sh/stable
sudo microk8s helm repo update
sudo microk8s helm install prometheus prometheus-community/kube-prometheus-stack
