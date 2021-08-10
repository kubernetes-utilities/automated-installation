#!/bin/sh
set -e
swapoff -a
sduo rm -f /etc/resolv.conf
sudo ln -s /run/systemd/resolve/resolv.conf /etc/resolv.conf
sudo sed -i -e 's/#DNS=/DNS=8.8.8.8/' /etc/systemd/resolved.conf
sudo sed -e '/^.*ubuntu2004.*/d' -i /etc/hosts
sudo cat >> /etc/hosts <<EOF
192.168.33.13 server
192.168.33.14 workera
192.168.33.15 workerb
EOF