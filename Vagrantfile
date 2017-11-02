static_ip = "172.16.0.8"

ingress_nginx_service = "---
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
spec:
  ports:
  - name: http
    port: 80
    targetPort: 80
  - name: https
    port: 443
    targetPort: 443
  selector:
    app: ingress-nginx
  externalIPs:
  - #{static_ip}
"

dashboard_admin = "---
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
"

dashboard_service = "---
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
  - #{static_ip}
"

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/xenial64"
  config.vm.provider "virtualbox" do |v|
	v.memory = 2048
	v.cpus = 2
  end
  config.vm.define "k8s" do |k8s|
	k8s.vm.hostname = "k8s"
	k8s.vm.network "private_network", ip: static_ip
	k8s.vm.provision "shell", inline: <<-SHELL
		# Adding repositories
		curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
		echo "deb https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
		curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
		echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
		# Install docker and kubernetes
		export DEBIAN_FRONTEND=noninteractive
		apt-get update && apt-get install -y kubelet kubeadm kubectl docker-ce=$(apt-cache madison docker-ce | grep 17.03 | head -1 | awk '{print $3}')
		# Initializing the cluster
		kubeadm init --apiserver-advertise-address=#{static_ip} --pod-network-cidr=192.168.0.0/16
		export KUBECONFIG=/etc/kubernetes/admin.conf
		# Install Calico networking
		kubectl apply -f https://docs.projectcalico.org/v2.6/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
		kubectl apply -f https://docs.projectcalico.org/v2.6/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
		# Untaint master
		kubectl taint nodes --all node-role.kubernetes.io/master-
		# Install nginx ingress proxy
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/namespace.yaml
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/default-backend.yaml
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/configmap.yaml
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/tcp-services-configmap.yaml
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/udp-services-configmap.yaml
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/rbac.yaml
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/with-rbac.yaml
		echo "#{ingress_nginx_service}" | kubectl apply -f -
		# Install Heapster for metrics
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/rbac/heapster-rbac.yaml
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/heapster/master/deploy/kube-config/standalone/heapster-controller.yaml
		# Install dashboard
		kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/alternative/kubernetes-dashboard.yaml
		echo "#{dashboard_admin}" | kubectl apply -f -
		echo "#{dashboard_service}" | kubectl replace --force -f -
		echo "Dashboard on http://#{static_ip}:9090"
		# Setting up the user's environment
		mkdir -p /home/ubuntu/.kube
		cp -i $KUBECONFIG /home/ubuntu/.kube/config
		chown ubuntu:ubuntu /home/ubuntu/.kube/config
		echo 'source <(kubectl completion bash)' >> /home/ubuntu/.bashrc
		adduser ubuntu docker > /dev/null
	SHELL
  end
end
