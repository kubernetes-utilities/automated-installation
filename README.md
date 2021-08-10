# automated-installation
Automate K8s installation in Ubuntu using Ansible and Vagrant in Ubuntu Virtualbox.


## Issue

### Worker Node Unable To Join The Cluster
The first attempt to join failed. So I added args `--apiserver-cert-extra-sans`

`kubeadm init --apiserver-advertise-address=192.168.33.13 --apiserver-cert-extra-sans=10.96.0.1,192.168.33.13,192.168.1.100 --pod-network-cidr=10.244.0.0/16 --cri-socket /run/containerd/containerd.sock`

Tried to join but did not work.
```
kubeadm join 10.0.2.15:6443 --token vk3qp4.zghvlarewt7w5419 --discovery-token-ca-cert-hash sha256:ddb8f359e15ec58c105130ebc58022583443f1dc2224235ea5b9633f5a864b82
[preflight] Running pre-flight checks
error execution phase preflight: couldn't validate the identity of the API Server: Get "https://10.0.2.15:6443/api/v1/namespaces/kube-public/configmaps/cluster-info?timeout=10s": dial tcp 10.0.2.15:6443: connect: connection refused
To see the stack trace of this error execute with --v=5 or higher
```

```
kubeadm join 192.168.1.100:6443 --token vk3qp4.zghvlarewt7w5419 --discovery-token-ca-cert-hash sha256:ddb8f359e15ec58c105130ebc58022583443f1dc2224235ea5b9633f5a864b82
[preflight] Running pre-flight checks
[preflight] Reading configuration from the cluster...
[preflight] FYI: You can look at this config file with 'kubectl -n kube-system get cm kubeadm-config -o yaml'
error execution phase preflight: unable to fetch the kubeadm-config ConfigMap: failed to get config map: Get "https://10.0.2.15:6443/api/v1/namespaces/kube-system/configmaps/kubeadm-config?timeout=10s": dial tcp 10.0.2.15:6443: connect: connection refused
To see the stack trace of this error execute with --v=5 or higher
```

Check clusters config
```
kubectl cluster-info dump
"annotations": {
    "flannel.alpha.coreos.com/backend-data": "{\"VNI\":1,\"VtepMAC\":\"36:26:ad:a9:39:44\"}",
    "flannel.alpha.coreos.com/backend-type": "vxlan",
    "flannel.alpha.coreos.com/kube-subnet-manager": "true",
    "flannel.alpha.coreos.com/public-ip": "10.0.2.15",
    "kubeadm.alpha.kubernetes.io/cri-socket": "/run/containerd/containerd.sock",
    "node.alpha.kubernetes.io/ttl": "0",
    "volumes.kubernetes.io/controller-managed-attach-detach": "true"
}

"spec": {
    "podCIDR": "10.244.0.0/24",
    "podCIDRs": [
        "10.244.0.0/24"
    ],
    "taints": [
        {
            "key": "node-role.kubernetes.io/master",
            "effect": "NoSchedule"
        }
    ]
},

"status": {
    "conditions": [
        {
            "type": "NetworkUnavailable",
            "status": "False",
            "lastHeartbeatTime": "2021-08-10T05:27:41Z",
            "lastTransitionTime": "2021-08-10T05:27:41Z",
            "reason": "FlannelIsUp",
            "message": "Flannel is running on this node"
        },
    ]
}
```

EXTERNAL-IP was not set so set it to the host IP thinking that would help, but did not.
```
kubectl get services --all-namespaces
NAMESPACE     NAME         TYPE        CLUSTER-IP   EXTERNAL-IP     PORT(S)                  AGE
default       kubernetes   ClusterIP   10.96.0.1    192.168.1.100   443/TCP                  5h20m
kube-system   kube-dns     ClusterIP   10.96.0.10   192.168.1.100   53/UDP,53/TCP,9153/TCP   5h20m

kubectl patch svc kubernetes -p '{"spec":{"externalIPs":["192.168.1.100"]}}'

kubectl patch svc default -p '{"spec":{"externalIPs":["192.168.1.100"]}}'

```

Reset the installation.
```
- kubeadm reset
- sudo iptables -F && sudo iptables -t nat -F && sudo iptables -t mangle -F && sudo iptables -X
- ipvsadm --clear - Had to install the tool. But should not be necessary as the `iptables` does the same thing.
```

Reinstalled.
```
kubeadm init --apiserver-advertise-address=192.168.33.13 --apiserver-cert-extra-sans=10.96.0.1,192.168.33.13,192.168.1.100 --pod-network-cidr=10.244.0.0/16 --cri-socket /run/containerd/containerd.sock`

- sed -e '/    - --port=0/d' -i /etc/kubernetes/manifests/kube-controller-manager.yaml
- sed -e '/    - --port=0/d' -i /etc/kubernetes/manifests/kube-scheduler.yaml
- systemctl restart kubelet.service

kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
```

Tried to join but failed again.
```
kubeadm join 192.168.33.13:6443 --token sr33zz.x05yxwlbg8llqpaw --discovery-token-ca-cert-hash sha256:458742c858214e5a62305af61817cfc256aa19e62206adbb3060fc9600413c45
[preflight] Running pre-flight checks
error execution phase preflight: couldn't validate the identity of the API Server: Get "https://192.168.33.13:6443/api/v1/namespaces/kube-public/configmaps/cluster-info?timeout=10s": dial tcp 192.168.33.13:6443: connect: no route to host
To see the stack trace of this error execute with --v=5 or higher
```

Checking if 192.168.33.13 is reachable? It's not!
```
ping 192.168.33.13
PING 192.168.33.13 (192.168.33.13) 56(84) bytes of data.
From 192.168.33.14 icmp_seq=1 Destination Host Unreachable
```

Tried cluster's host IP
```
kubeadm join 192.168.1.100:6443 --token vk3qp4.zghvlarewt7w5419 --discovery-token-ca-cert-hash sha256:ddb8f359e15ec58c105130ebc58022583443f1dc2224235ea5b9633f5a864b82
[preflight] Running pre-flight checks
error execution phase preflight: couldn't validate the identity of the API Server: could not find a JWS signature in the cluster-info ConfigMap for token ID "vk3qp4"
```

Tried 10.0.2.15, but did not work.
```
sudo kubeadm join 10.0.2.15:6443 --token vk3qp4.zghvlarewt7w5419 --discovery-token-ca-cert-hash sha256:ddb8f359e15ec58c105130ebc58022583443f1dc2224235ea5b9633f5a864b82
[preflight] Running pre-flight checks
error execution phase preflight: couldn't validate the identity of the API Server: Get "https://10.0.2.15:6443/api/v1/namespaces/kube-public/configmaps/cluster-info?timeout=10s": dial tcp 10.0.2.15:6443: connect: connection refused
To see the stack trace of this error execute with --v=5 or higher
```

From worker's guest virtual machine, check if those IP address which were we tried to join is listening to the port or is reachable.
```
nc -vz 10.0.2.15 6443
nc: connect to 10.0.2.15 port 6443 (tcp) failed: Connection refused

nc -vz 192.168.1.100 6443
Connection to 192.168.1.100 6443 port [tcp/*] succeeded!

nc -vz 192.168.33.13 6443
nc: connect to 192.168.33.13 port 6443 (tcp) failed: No route to host
```

> IP Tables

VM ip-table
`ip a`
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:09:05:5f brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic eth0
       valid_lft 62466sec preferred_lft 62466sec
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:d2:fb:e4 brd ff:ff:ff:ff:ff:ff
    inet 192.168.33.14/24 brd 192.168.33.255 scope global eth1
       valid_lft forever preferred_lft forever


The IP is also not reachable from host but it does show up in the ip table.
`ip a`
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: enp8s0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc fq_codel state DOWN group default qlen 1000
    link/ether f0:76:1c:65:6f:1d brd ff:ff:ff:ff:ff:ff
3: wlp9s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether d0:53:49:57:e3:57 brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.73/24 brd 192.168.1.255 scope global dynamic noprefixroute wlp9s0
       valid_lft 80935sec preferred_lft 80935sec
    inet6 2403:3800:322b:123:c035:4e4f:de29:5562/64 scope global temporary dynamic 
       valid_lft 86350sec preferred_lft 80729sec
    inet6 2403:3800:322b:123:9c53:f690:7b7d:2448/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86350sec preferred_lft 86350sec
    inet6 fe80::9e69:bb68:4b99:a6f3/64 scope link noprefixroute 
       valid_lft forever preferred_lft forever
10: vboxnet0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 0a:00:27:00:00:00 brd ff:ff:ff:ff:ff:ff
    inet 192.168.33.1/24 brd 192.168.33.255 scope global vboxnet0
       valid_lft forever preferred_lft forever
    inet6 fe80::800:27ff:fe00:0/64 scope link 
       valid_lft forever preferred_lft forever

Cluster Admin GUEST Virtual Machine IP Table
```
ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:3a:79:bf brd ff:ff:ff:ff:ff:ff
    inet 10.0.2.15/24 brd 10.0.2.255 scope global dynamic eth0
       valid_lft 63836sec preferred_lft 63836sec
    inet6 fe80::a00:27ff:fe3a:79bf/64 scope link 
       valid_lft forever preferred_lft forever
3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 08:00:27:68:10:7e brd ff:ff:ff:ff:ff:ff
    inet 192.168.33.13/24 brd 192.168.33.255 scope global eth1
       valid_lft forever preferred_lft forever
    inet6 fe80::a00:27ff:fe68:107e/64 scope link 
       valid_lft forever preferred_lft forever
4: flannel.1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UNKNOWN group default 
    link/ether 36:26:ad:a9:39:44 brd ff:ff:ff:ff:ff:ff
    inet 10.244.0.0/32 brd 10.244.0.0 scope global flannel.1
       valid_lft forever preferred_lft forever
5: cni0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP group default qlen 1000
    link/ether 72:f9:6e:be:9c:6f brd ff:ff:ff:ff:ff:ff
    inet 10.244.0.1/24 brd 10.244.0.255 scope global cni0
       valid_lft forever preferred_lft forever
10: veth68f6b528@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue master cni0 state UP group default 
    link/ether f2:50:be:16:e7:c9 brd ff:ff:ff:ff:ff:ff link-netns cni-dcfd1f57-2bfb-3a14-f775-9c7cbaf0bf6c
11: veth9e9d758d@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue master cni0 state UP group default 
    link/ether fa:95:92:52:c1:4d brd ff:ff:ff:ff:ff:ff link-netns cni-02d33b72-13b4-1fc1-b0f4-f4c16a0b9732
```

Cluster Admin host ip table
```
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: enp3s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 3c:4a:92:55:34:84 brd ff:ff:ff:ff:ff:ff
    inet 192.168.1.100/24 brd 192.168.1.255 scope global dynamic noprefixroute enp3s0
       valid_lft 44899sec preferred_lft 44899sec
    inet6 2403:3800:322b:123:d8e:8f87:5a76:9c05/64 scope global temporary dynamic 
       valid_lft 86089sec preferred_lft 83832sec
    inet6 2403:3800:322b:123:65c6:597f:3567:ecec/64 scope global temporary deprecated dynamic 
       valid_lft 86089sec preferred_lft 0sec
    inet6 2403:3800:322b:123:f869:f008:fc47:3e4d/64 scope global temporary deprecated dynamic 
       valid_lft 86089sec preferred_lft 0sec
    inet6 2403:3800:322b:123:4997:f33b:1bd1:1f1d/64 scope global temporary deprecated dynamic 
       valid_lft 86089sec preferred_lft 0sec
    inet6 2403:3800:322b:123:344d:65e8:256b:a25d/64 scope global temporary deprecated dynamic 
       valid_lft 86089sec preferred_lft 0sec
    inet6 2403:3800:322b:123:685f:1940:df24:30a0/64 scope global temporary deprecated dynamic 
       valid_lft 86089sec preferred_lft 0sec
    inet6 2403:3800:322b:123:f5bf:f05b:8c93:5f5b/64 scope global temporary deprecated dynamic 
       valid_lft 86089sec preferred_lft 0sec
    inet6 2403:3800:322b:123:91ea:8242:d2f4:9d18/64 scope global temporary deprecated dynamic 
       valid_lft 275sec preferred_lft 0sec
    inet6 2403:3800:322b:123:a9f4:47ad:e00c:463a/64 scope global dynamic mngtmpaddr noprefixroute 
       valid_lft 86089sec preferred_lft 86089sec
    inet6 fe80::21f2:2000:9a2a:2e4d/64 scope link noprefixroute 
3: wlp2s0b1: <BROADCAST,MULTICAST> mtu 1500 qdisc noop state DOWN group default qlen 1000
    link/ether e0:2a:82:fb:d5:cc brd ff:ff:ff:ff:ff:ff
4: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:91:be:07:3f brd ff:ff:ff:ff:ff:ff
    inet 172.17.0.1/16 brd 172.17.255.255 scope global docker0
       valid_lft forever preferred_lft forever
5: br-6f507f240f54: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:ed:92:bd:ab brd ff:ff:ff:ff:ff:ff
    inet 172.20.0.1/16 brd 172.20.255.255 scope global br-6f507f240f54
       valid_lft forever preferred_lft forever
    inet6 fc00:f853:ccd:e793::1/64 scope global tentative 
       valid_lft forever preferred_lft forever
    inet6 fe80::1/64 scope link tentative 
       valid_lft forever preferred_lft forever
6: br-847829250b8c: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:a0:ce:67:5d brd ff:ff:ff:ff:ff:ff
    inet 172.19.0.1/16 brd 172.19.255.255 scope global br-847829250b8c
       valid_lft forever preferred_lft forever
7: br-940c3874b064: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:33:0a:ed:c9 brd ff:ff:ff:ff:ff:ff
    inet 172.18.0.1/16 brd 172.18.255.255 scope global br-940c3874b064
       valid_lft forever preferred_lft forever
8: virbr0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default qlen 1000
    link/ether 52:54:00:37:80:14 brd ff:ff:ff:ff:ff:ff
    inet 192.168.122.1/24 brd 192.168.122.255 scope global virbr0
       valid_lft forever preferred_lft forever
9: virbr0-nic: <BROADCAST,MULTICAST> mtu 1500 qdisc fq_codel master virbr0 state DOWN group default qlen 1000
    link/ether 52:54:00:37:80:14 brd ff:ff:ff:ff:ff:ff
10: vboxnet0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 0a:00:27:00:00:00 brd ff:ff:ff:ff:ff:ff
    inet 192.168.33.1/24 brd 192.168.33.255 scope global vboxnet0
       valid_lft forever preferred_lft forever
    inet6 fe80::800:27ff:fe00:0/64 scope link 
       valid_lft forever preferred_lft forever
```

## Restart Again

kubeadm token create --print-join-command
kubectl -n kube-system get cm kubeadm-config -o yaml
echo $(/sbin/ip -o -4 addr list eth1 | awk '{print $4}' | cut -d/ -f1)
echo $(/sbin/ip -o -4 addr list wlp9s0 | awk '{print $4}' | cut -d/ -f1)
sudo ss -tunlp
nc -vz 192.168.33.13 6443

# Resource
- https://github.com/kubernetes/kubernetes/issues/58876
- https://github.com/kubernetes/kubernetes/issues/90345
- https://discuss.kubernetes.io/t/the-connection-to-the-server-host-6443-was-refused-did-you-specify-the-right-host-or-port/552
- https://www.titanwolf.org/Network/q/efa1c675-1d57-4111-b6c2-7a104a0d9519
- https://developers.caffeina.com/a-kubernetes-cluster-on-virtualbox-20d64666a678
- https://developers.caffeina.com/use-virtualbox-interface-headless-with-ssh-5552bf793d5f
- https://stackoverflow.com/questions/61305498/kubernetes-couldnt-able-to-join-master-node-error-execution-phase-preflight
- https://unix.stackexchange.com/questions/330896/destination-host-unreachable-between-host-and-guest-kvm
- https://kubernetes.io/docs/tutorials/stateless-application/expose-external-ip-address
- https://unix.stackexchange.com/questions/330896/destination-host-unreachable-between-host-and-guest-kvm
- https://serverfault.com/questions/923707/accessing-kubernetes-service-using-hostname-ip-address
- https://stackoverflow.com/questions/53860822/cannot-join-a-kubernetes-cluster
- https://github.com/kubernetes/kubeadm/issues/1596
- **https://stackoverflow.com/questions/44519980/assign-external-ip-to-a-kubernetes-service**
- **https://kevinhoffman.medium.com/building-a-kubernetes-cluster-in-virtualbox-with-ubuntu-22cd338846dd**
- **https://devops.stackexchange.com/questions/9483how-can-i-add-an-additional-ip-hostname-to-my-kubernetes-certificate**
- Docker is required for container runtime even though I am using containerd
 https://github.com/kubernetes/kubeadm/issues/2364 - `kubectl annotate node kube-master --overwrite kubeadm.alpha.kubernetes.io/cri-socket=unix:///run/containerd/containerd.sock`
- https://linuxize.com/post/how-to-configure-static-ip-address-on-ubuntu-20-04
- https://linuxconfig.org/how-to-turn-on-off-ip-forwarding-in-linux
- **https://github.com/justsomedevnotes/kubernetes-kubeadm-virtualbox**
- **https://github.com/mbaykara/k8s-cluster/blob/main/k8s-setup-master.sh**
- https://vitalflux.com/kubernetes-create-delete-namespaces-namespaces
- https://www.learnsteps.com/how-exactly-kube-proxy-works-basics-on-kubernetes


Untainting the Master Node
kubectl taint nodes --all node-role.kubernetes.io/master-

# Note
Kube-proxy is making configurations so that packets can reach their destination when you call a service and not routing the packets. Kube-proxy creates iptables rules for the services that are created. Kube proxy runs on each node and talks to api-server to get the details of the services and endpoints present. Based on this information, kube-proxy creates entries in iptables, which then routes the packets to the correct destination. 

Kubelet is an agent or program which runs on each node. This is responsible for all the communications between the Kubernetes control plane [group of programs which control kubernetes] and the nodes where the actual workload runs. Kubelet is like a captain of nodes and everything that needs to be executed on a node has to be done through kubelet. 

etcd is distributed key-value store and it is strongly consistent. etcd works on the concept of leader and slaves. In most of cases it has 3 or 5 nodes for the quorum. It uses raft protocol for leader election. Only one node at a time is serving read and write in the etcd cluster. etcd acts as a backend to Kubernetes. Everything you create or make changes to is stored as a key-value in etcd. It is like a database of all the states of Kubernetes. If you have launched a Kubernetes with the same etcd backup, you will end up in almost the same state as it was before.