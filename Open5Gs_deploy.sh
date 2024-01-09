#!/bin/bash
sudo helm repo add openverso https://gradiant.github.io/openverso-charts/
sudo helm install open5gs openverso/open5gs --version 2.0.8 --values https://gradiant.github.io/openverso-charts/docs/open5gs-ueransim-gnb/5gSA-values.yaml

#!/bin/bash
#sudo microk8s enable dns
#sudo microk8s enable dashboard
#sudo microk8s enable storage
#sudo microk8s kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.22/deploy/local-path-storage.yaml
#sudo microk8s kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
#sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
#sudo chmod 700 get_helm.sh
#sudo ./get_helm.sh
#sudo helm repo add openverso https://gradiant.github.io/openverso-charts/
#sudo helm repo update
#sudo microk8s kubectl config view --raw > ~/.kube/config
#sudo  helm install open5gs openverso/open5gs --version 2.0.8 --values https://gradiant.github.io/openverso-charts/docs/open5gs-ueransim-gnb/5gSA-values.yaml
# sudo microk8s helm install ueransim-gnb openverso/ueransim-gnb --version 0.2.2 --values https://gradiant.github.io/openverso-charts/docs/open5gs-ueransim-gnb/gnb-ues-values.yaml
