#!/bin/bash

#set -Eeuo pipefail
#trap cleanup SIGINT SIGTERM ERR EXIT

installVirtualbox(){
    sudo apt update -y 
    sudo apt install -y virtualbox
    mkdir $HOME/virtualbox 
    vm setproperty machinefolder $HOME/virtualbox
}

installVagrant() {
    cd /tmp
    export VERSION=$(curl -s https://api.github.com/repos/hashicorp/vagrant/tags | jq ".[0].name" | cut -c 3-8)
    curl -O https://releases.hashicorp.com/vagrant/$VERSION/vagrant_{$VERSION}_x86_64.deb
    chmod 755 vagrant_$(echo $VERSION)_x86_64.deb
    sudo apt install ./\vagrant_$(echo $VERSION)_x86_64.deb
    rm -f vagrant_$(echo $VERSION)_x86_64.deb
}

resolveDNS() {
    sduo rm -f /etc/resolv.conf
    sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf

    sudo sed -i -e 's/#DNS=/DNS=8.8.8.8/' /etc/systemd/resolved.conf
}

addHosts() {
    sudo sed -e '/^.*ubuntu2004.*/d' -i /etc/hosts
    sudo sed -e '/^.*hp-admin*/d' -i /etc/hosts

    # Update /etc/hosts about other hosts
sudo cat >> /etc/hosts <<EOF

# Add hosts
192.168.33.13 hp-admin
192.168.33.14 worker-1
192.168.33.15 worker-2
EOF

}

cleanIP(){
sudo cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

    sudo echo '1' > /proc/sys/net/ipv4/ip_forward

    sudo sysctl --system
}

modprobe(){
    sudo modprobe overlay
    sudo modprobe br_netfilter
    sudo service systemd-resolved restart
}

setupNetwork() {
    resolveDNS
    addHosts
    cleanIP
    modprobe
}

installBasic() {
    sudo apt-get update -y
    sudo apt-get install -y apt-transport-https gnupg2 curl containerd

    sudo mkdir -p /etc/containerd
    sudo containerd config default > /etc/containerd/config.toml

    sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg \
        https://packages.cloud.google.com/apt/doc/apt-key.gpg    
    
    echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] \
        https://apt.kubernetes.io/ kubernetes-xenial main" \
        | sudo tee /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update -y && apt-get upgrade -y

}

swapoff(){
    sudo swapoff -a
}

setup() {
    swapoff
    setupNetwork
    installBasic
}

master() {
    sudo apt-get install -y kubeadm kubectl kubelet
    sudo apt-mark hold kubeadm kubectl kubelet
    
    initMaster
    addAdminConfig
    installFlannel

    aliasKubectl
}

worker() {
    sudo apt-get install -y kubelet
}

aliasKubectl() {
    sudo apt-get install -y bash-completion
    echo 'alias k=kubectl' >>~/.bashrc
    echo 'complete -F __start_kubectl k' >>~/.bashrc    
    echo 'source <(kubectl completion bash)' >>~/.bashrc
}

initMaster() {
    sudo su 
    kubeadm init --apiserver-advertise-address 192.168.33.13 --pod-network-cidr=10.244.0.0/16
    
    # https://stackoverflow.com/questions/64296491/how-to-resolve-scheduler-and-controller-manager-unhealthy-state-in-kubernetes
    # kubectl get cs / kubectl get componentstatuses
    sed -e '/    - --port=0/d' -i /etc/kubernetes/manifests/kube-controller-manager.yaml
    sed -e '/    - --port=0/d' -i /etc/kubernetes/manifests/kube-scheduler.yaml
    systemctl restart kubelet.service

    exit
}

addAdminConfig() {
    mkdir -p /home/vagrant/.kube
    sudo cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
    sudo chown vagrant:vagrant /home/vagrant/.kube/config
}

installFlannel(){
    sudo kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
}

main() {
    setup

    if [ "$1" == "master" ]; then
        master
    fi

    worker
}

if [ "$1" == "" ]; then
    echo "ERROR: The 1 argument is empty"
fi

main $1

# echo "The number of arguments passed to the script is: $#"
# for ITEM in "$@"
# do
#     echo $ITEM
# done