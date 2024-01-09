#!/bin/bash
sudo snap install microk8s --classic
sudo usermod -aG microk8s ubuntu
sudo mkdir -p /home/ubuntu/.kube
sudo chown -Rf ubuntu /home/ubuntu/.kube
sudo microk8s enable dns ingress
sudo snap alias microk8s.kubectl kubectl
sudo snap alias microk8s.helm helm
sudo microk8s kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.22/deploy/local-path-storage.yaml
sudo microk8s kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
microk8s install

###!/bin/bash
#sudo snap install microk8s --classic
#sudo snap wait system seed.loaded
#sudo mkdir $HOME -p .kube
#sudo chown -f -R ubuntu ~/.kube
#sudo microk8s config > ~/.kube/config
#sudo usermod -a -G microk8s ubuntu
#sudo chown -R ubuntu ~/.kube

