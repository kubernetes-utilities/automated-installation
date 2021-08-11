#!/bin/sh
set -e
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl -w net.ipv4.ip_forward=1
sudo sysctl net.bridge.bridge-nf-call-iptables=1
sudo sysctl --system
sudo modprobe overlay
sudo modprobe br_netfilter
sudo service systemd-resolved restart

sudo -s <<EOF
kubeadm init --apiserver-advertise-address \
    192.168.33.13 --pod-network-cidr=10.244.0.0/16 \
    --cri-socket /run/containerd/containerd.sock \
    --apiserver-cert-extra-sans=10.96.0.1,192.168.33.13,192.168.1.100
export KUBECONFIG=/etc/kubernetes/admin.conf
sed -e '/    - --port=0/d' -i /etc/kubernetes/manifests/kube-controller-manager.yaml
sed -e '/    - --port=0/d' -i /etc/kubernetes/manifests/kube-scheduler.yaml
systemctl restart kubelet
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
EOF

# Non-root user config
# user_config() {
#    mkdir -p $HOME/.kube
#    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#    sudo chown $(id -u):$(id -g) $HOME/.kube/config
#    echo 'alias k=kubectl' >>~/.bashrc
# }

# https://stackoverflow.com/questions/64296491/how-to-resolve-scheduler-and-controller-manager-unhealthy-state-in-kubernetes

# Validate more IP in the certificate with `--apiserver-cert-extra-sans`
# kubeadm init --apiserver-advertise-address=192.168.1.100 --apiserver-cert-extra-sans=10.96.0.1,192.168.33.13,192.168.1.100 --pod-network-cidr=10.244.0.0/16 --cri-socket /run/containerd/containerd.sock