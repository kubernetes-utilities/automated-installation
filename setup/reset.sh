#!/bin/sh
set -e
sudo kubeadm reset
sudo iptables -F \
    && sudo iptables -t nat -F \
    && sudo iptables -t mangle -F \
    && sudo iptables -X
sudo rm -rf /etc/cni/net.d