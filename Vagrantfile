Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/xenial64"
  config.vm.hostname = "k8s"
  config.vm.network "private_network", type: "dhcp"
  config.vm.provision "shell", inline: <<-SHELL
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
	echo "deb https://download.docker.com/linux/$(lsb_release -si | tr '[:upper:]' '[:lower:]') $(lsb_release -cs) stable" > /etc/apt/sources.list.d/docker.list
	curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
	echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" > /etc/apt/sources.list.d/kubernetes.list
	apt-get update && apt-get install -y kubelet kubeadm kubectl docker-ce=$(apt-cache madison docker-ce | grep 17.03 | head -1 | awk '{print $3}')
	kubeadm init --skip-token-print --pod-network-cidr=192.168.0.0/16
	export KUBECONFIG=/etc/kubernetes/admin.conf
	kubectl apply -f https://docs.projectcalico.org/v2.6/getting-started/kubernetes/installation/hosted/rbac-kdd.yaml
	kubectl apply -f https://docs.projectcalico.org/v2.6/getting-started/kubernetes/installation/hosted/kubernetes-datastore/calico-networking/1.7/calico.yaml
	kubectl taint nodes --all node-role.kubernetes.io/master-
	mkdir -p /home/ubuntu/.kube
	cp -i $KUBECONFIG /home/ubuntu/.kube/config
	chown ubuntu:ubuntu /home/ubuntu/.kube/config
	echo 'source <(kubectl completion bash)' >> /home/ubuntu/.bashrc
	adduser ubuntu docker
  SHELL
end