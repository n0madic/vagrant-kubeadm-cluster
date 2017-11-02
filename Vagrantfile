static_ip = "172.16.0.8"

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/xenial64"
  config.vm.provider "virtualbox" do |v|
	v.memory = 2048
	v.cpus = 2
  end
  config.vm.define "k8s" do |k8s|
	k8s.vm.hostname = "k8s"
	k8s.vm.network "private_network", ip: static_ip
	k8s.vm.provision "shell" do |shell|
		shell.path = "provision.sh"
		shell.env = {"STATIC_IP" => static_ip}
	end
  end
end
