# DEPRECATED

Please look at other deployment options for production ready Kubernetes
clusters on Exoscale

* [Cluster API](https://cluster-api.sigs.k8s.io/reference/providers.html)
* Native managed kubernetes from Exoscale
* Rancher and other control panels

# Multi-master Kubernetes

This Ansible playbook helps you setup a multi-master
[Kubernetes](http://kubernetes.io/) cluster on
[Exoscale](https://www.exoscale.com/).

## Getting started

To run this playbook a working Docker installation and a basic understanding
of containers and volumes is required. You also need a Exoscale account and
the corresponding API key and secret.

You can get your key and secret here:
https://portal.exoscale.com/account/profile/api

Let's bootstrap a cluster.

```
# Run the container and mount a data volume for the cluster specific secrets
docker run -ti -v k8s_secrets:/secret exoscale/multi-master-kubernetes

# Set EXO_API_KEY and EXO_API_SECRET environment variables
export EXO_API_KEY=
export EXO_API_SECRET=

# Then run the cluster-bootstrap playbook
ansible-playbook cluster-bootstrap.yml
```

> Tip: The cluster-bootstrap playbook is safe to re-run at any time
> to make sure your cluster is configured correctly.

Bootstrapping the cluster takes a few minutes. When the playbook finishes,
you can see the cluster nodes come up using:

```
kubectl get nodes -w
```

> Note: kubectl is setup automatically inside the container. To use it outside
> the container as well, simply get the `kubeconfig` file from that data volume
> and copy it into `~/.kube/config`

## Add more worker nodes

If you want to add more workers simply run the worker-add playbook.
Specify the desired number of worker nodes. The default cluster has 3 worker
nodes. Below command adds 2 more for a total of 5.

```
ansible-playbook -e desired_num_worker_nodes=5 worker-add.yml
```

## Update Kubernetes

The cluster-upgrade playbook takes care of one by one updating Kubernetes on
each of the nodes and restarting services as required. The upgrade does lead to
a short unavailability of the apiserver due to the restart of the etcd members.
Member restarts take a couple of retries before they succeed, this is caused by
ports still being in use.

```
ansible-playbook cluster-upgrade.yml
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
 * haproxy
 * and your containers of course

Flanneld, Locksmithd, Docker, infra-etcd2 and the kubelet are started using
Systemd. All other components most notably kubernetes-etcd2 and kube-* are
started by the kubelet.

CoreOS is configured to do automatic updates. Locksmith is configured to make
sure only one of the six cluster nodes reboots at the same time. It is also
configured to ensure a maintenance window for master nodes between 4 and 5am
and for worker nodes between 5 and 6am daily. Automatic updates only include
the OS components that are part of CoreOS.

## Ingress

Cluster bootstrap includes the nginx-ingress-controller to make services
available externally using ingress resources.

Haproxy on each worker node listens on `0.0.0.0:80` and `0.0.0.0:443` and
forwards TCP traffic to the ingress controller service.

Simply setup a wildcard DNS entry to point to the IPs of your worker nodes.

[Kube-lego](https://github.com/jetstack/kube-lego) is supported by the
nginx-ingress-controller but is not automatically installed.

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
