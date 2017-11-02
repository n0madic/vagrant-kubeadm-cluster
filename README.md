# vagrant-kubeadm-cluster
Ready to use single-host kubernetes cluster deployed in Vagrant using kubeadm with dashboard and ingress proxy.
Alternative to Minikube.

Usage:
```
$ git clone https://github.com/n0madic/vagrant-kubeadm-cluster.git
$ cd vagrant-kubeadm-cluster
$ vagrant up
$ vagrant ssh
ubuntu@k8s:~$ kubectl get all --all-namespaces
```
Dashboard is available at a private static address http://172.16.0.8:9090
