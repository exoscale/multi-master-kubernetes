# Multi-master Kubernetes

This Ansible playbook helps you setup a multi-master
[Kubernetes](http://kubernetes.io/) cluster on
[Exoscale](https://www.exoscale.ch/).

## Getting started

To bootstrap your cluster, install the requirements via `pip` and put `kubectl`
in your path. Then run the playbook.

> Warning: Ansible doesn't play nice in a Virtualenv on systems with Selinux.
> To fix this, make sure you have python-selinux bindings installed and include
> system packages in your virtualenv.

```
# only required when selinux is enabled
sudo dnf install libselinux-python

virtualenv --system-site-packages .venv
source .venv/bin/activate

# install the requirements
pip install -r requirements.txt

# run the Ansible playbook
ansible-playbook cluster-bootstrap.yml
```

> Tip: The cluster-bootstrap playbook is safe to re-run at any time
> to make sure your cluster is configured correctly.

Bootstrapping the cluster takes a few minutes. When the playbook finishes,
you can see the cluster nodes come up using:

```
kubectl get nodes -w
```

## Add more worker nodes

If you want to add more workers simply run the worker-add playbook.
Specify the desired number of worker nodes. The default cluster has 3 worker
nodes. Below command adds 2 more for a total of 5.

```
ansible-playbook -e desired_num_worker_nodes=5 worker-add.yml
```

## Architecture

The initial cluster consists of 3 master nodes and 3 worker nodes. Master nodes
are pets, worker nodes are cattle. All nodes run CoreOS.

__Master nodes run:__

 * infra-etcd2: Etcd2 cluster used for Flanneld overlay networking and
   Locksmithd
 * flanneld: for the container overlay network
 * locksmithd: to orchestrate automatic updates
 * dockerd
 * kubelet
 * kubernetes-etcd2: Etcd2 cluster used for Kubernetes
 * kube-apiserver
 * kube-scheduler
 * kube-controller-manager
 * kube-proxy

__Worker nodes run:__

 * flanneld: for the container overlay network
 * locksmithd: to orchestrate automatic updates
 * dockerd
 * kubelet
 * kube-proxy
 * haproxy: to workaround kubelet and kube-proxy single apiserver limitation
 * and your containers of course

Flanneld, Locksmithd, Docker, infra-etcd2 and the kubelet are started using
Systemd. All other components most notably kubernetes-etcd2 and kube-* are
started by the kubelet.

CoreOS is configured to do automatic updates. Locksmith is configured to make
sure only one of the six cluster nodes reboots at the same time. It is also
configured to ensure a maintenance window for master nodes between 4 and 5am
and for worker nodes between 5 and 6am daily. Automatic updates only include
the OS components that are part of CoreOS.

## Security

Master and worker nodes each have their own security-groups and only open
the required ports between nodes within the same group or between nodes of the
other group respectively.

All nodes allow external SSH access. (Required for Ansible unless you use a
bastion host.)

On top of the firewall rules enforced by the security groups, all components are
configured to communicate via TLS using certificates.

The required certificate authorities and certificates are generated using cfssl
automatically.

## Known issues / limitations

### Kubectl

kubectl is configured to talk to the first master node via IP. If the first
master node is unavailable, you need to update your kubectl config to talk
to another master node or bring the master node back up.
You can of course setup DNS A records for each one of your nodes and use
a DNS name instead of the IP in your config.

### Kube-dns

kube-dns sometimes fails to come up due to a race condition. The pod starts
before the service account token is created. To fix this. Simply delete the
pod.

```
kubectl --namespace=kube-system delete pod \
$( kubectl --namespace=kube-system get pods \
    -l k8s-app=kube-dns -o jsonpath={.items[0]..metadata.name} )
```
