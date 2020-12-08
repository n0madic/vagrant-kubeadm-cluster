#!/bin/bash
set -eo pipefail

echo '### Adding repositories ###'
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -yq apt-transport-https curl
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
echo "deb https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

echo '### Install containerd and kubernetes ###'
apt-get update -qq && apt-get install -yqq containerd.io kubelet=$KUBE_VERSION* kubeadm=$KUBE_VERSION* kubectl=$KUBE_VERSION*

echo '### Disable swap ###'
sed -i -e '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a

echo '### Initializing the containerd ###'
modprobe overlay
modprobe br_netfilter
cat <<EOF > /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
cat <<EOF > /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sysctl --quiet --system
containerd config default > /etc/containerd/config.toml
systemctl restart containerd

if [[ "$SKIP_INIT" -eq 1 ]]; then
  echo 'SKIP cluster initialization!'
  exit;
fi

echo '### Initializing the k8s cluster ###'
kubeadm init --kubernetes-version=$KUBE_VERSION --apiserver-advertise-address=$STATIC_IP --pod-network-cidr=192.168.0.0/16
export KUBECONFIG=/etc/kubernetes/admin.conf

echo '### Setting up the user environment ###'
chmod +r /etc/kubernetes/admin.conf
echo "export KUBECONFIG=/etc/kubernetes/admin.conf" > /etc/profile.d/kube.sh
echo "source <(kubectl completion bash)" >> /etc/profile.d/kube.sh
echo "alias docker='sudo /usr/bin/docker'" > /etc/profile.d/docker.sh

echo '### Untaint master ###'
kubectl taint nodes --all node-role.kubernetes.io/master-

if [[ "$SKIP_CNI" -eq 1 ]]; then
  echo 'SKIP CNI network installing!'
else
  echo '### Install Calico networking ###'
  kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
fi

if [[ "$SKIP_INGRESS" -eq 1 ]]; then
  echo 'SKIP ingress installing!'
  exit;
fi

echo '### Install nginx ingress proxy ###'
kubectl apply -f https://github.com/kubernetes/ingress-nginx/raw/master/deploy/static/provider/baremetal/deploy.yaml
cat <<EOF | kubectl replace --force -f -
  apiVersion: v1
  kind: Service
  metadata:
    name: ingress-nginx-controller
    namespace: ingress-nginx
    labels:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/instance: ingress-nginx
      app.kubernetes.io/component: controller
  spec:
    ports:
      - name: http
        port: 80
        targetPort: 80
        protocol: TCP
      - name: https
        port: 443
        targetPort: 443
        protocol: TCP
    selector:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/instance: ingress-nginx
      app.kubernetes.io/component: controller
    externalIPs:
    - $STATIC_IP
EOF
kubectl wait --timeout=300s --for=condition=available -n ingress-nginx deployment/ingress-nginx-controller

if [[ "$SKIP_DASHBOARD" -eq 1 ]]; then
  echo 'SKIP dashboard installing!'
  exit;
fi

echo '### Install dashboard ###'
kubectl apply -f https://github.com/kubernetes/dashboard/raw/master/aio/deploy/alternative.yaml
cat <<EOF | kubectl replace --force -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
EOF
cat <<EOF | kubectl apply --timeout=30s -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kubernetes-dashboard
  namespace: kubernetes-dashboard
spec:
  rules:
  - host: localhost
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kubernetes-dashboard
            port:
              number: 80
EOF
kubectl wait --timeout=300s --for=condition=available -n kubernetes-dashboard deployment/kubernetes-dashboard
echo ">>> Dashboard on http://localhost:8080 <<<"
echo "Token: $(kubectl get -n kubernetes-dashboard secrets `kubectl -n kubernetes-dashboard get serviceaccount kubernetes-dashboard -o 'jsonpath={.secrets[0].name}'` -o jsonpath={.data.token} | base64 -d)"
