static_ip = '172.16.0.8'

Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu/xenial64'
  config.vm.box_check_update = false
  config.vm.provider 'virtualbox' do |v|
    v.memory = 4096
    v.cpus = 2
  end
  config.vm.define 'k8s' do |k8s|
    k8s.vm.hostname = 'k8s'
    k8s.vm.network 'private_network', ip: static_ip
    k8s.vm.network "forwarded_port", guest_ip: static_ip, guest: 80, host: 8080
    k8s.vm.network "forwarded_port", guest_ip: static_ip, guest: 443, host: 8443
    k8s.vm.provision 'shell' do |shell|
      shell.path = 'provision.sh'
      shell.env = {
        'STATIC_IP' => static_ip,
        'KUBE_VERSION' => ENV['KUBE_VERSION'],
        'SKIP_INIT' => ENV['SKIP_INIT'],
        'SKIP_CNI' => ENV['SKIP_CNI'],
        'SKIP_INGRESS' => ENV['SKIP_INGRESS'],
        'SKIP_DASHBOARD' => ENV['SKIP_DASHBOARD']
      }
    end
  end
end
