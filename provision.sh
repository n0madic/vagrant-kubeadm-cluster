#!/bin/bash
set -eo pipefail

echo '### Adding repositories ###'
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get install -yq apt-transport-https curl
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
echo "deb https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list

echo '### Install docker and kubernetes ###'
apt-get update -qq && apt-get install -yq kubelet=$KUBE_VERSION* kubeadm=$KUBE_VERSION* kubectl=$KUBE_VERSION* docker-ce=18.06*

echo '### Disable swap ###'
sed -i -e '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
swapoff -a

if [[ "$SKIP_INIT" -eq 1 ]]; then
  echo 'SKIP cluster initialization!'
  exit;
fi

echo '### Initializing the cluster ###'
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
  kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
fi

if [[ "$SKIP_INGRESS" -eq 1 ]]; then
  echo 'SKIP ingress installing!'
else
  echo '### Install nginx ingress proxy ###'
  kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/static/mandatory.yaml
cat <<EOF | kubectl create -f -
  apiVersion: v1
  kind: Service
  metadata:
    name: ingress-nginx
    namespace: ingress-nginx
    labels:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/part-of: ingress-nginx
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
      app.kubernetes.io/part-of: ingress-nginx
    externalIPs:
    - $STATIC_IP
EOF
fi

if [[ "$SKIP_DASHBOARD" -eq 1 ]]; then
  echo 'SKIP dashboard installing!'
  exit;
fi

echo '### Install dashboard ###'
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v1.10.1/src/deploy/alternative/kubernetes-dashboard.yaml
cat <<EOF | kubectl create -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
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
  namespace: kube-system
EOF
cat <<EOF | kubectl replace --force -f -
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  ports:
  - port: 9090
    targetPort: 9090
  selector:
    k8s-app: kubernetes-dashboard
  externalIPs:
  - $STATIC_IP
EOF
kubectl wait --timeout=300s --for=condition=available -n kube-system deployment/kubernetes-dashboard
echo ">>> Dashboard on http://$STATIC_IP:9090 <<<"
