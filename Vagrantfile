# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "generic/ubuntu2004"
  
  config.vm.define "b50-admin" do | m |
    m.vm.hostname = "b50-admin"
    
    m.vm.network "private_network", ip: "192.168.33.13"
    
    m.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
      vb.cpus = 2
      vb.name = "b50-admin"
    end
    
    config.vm.network "forwarded_port", id:"SSH",
      guest_ip: "192.168.33.13", guest: 22, 
      host_ip: "192.168.1.73", host: 3313
      
    # config.vm.provision:shell, inline: <<-SHELL
    #     sudo su
    # SHELL

    config.vm.provision "shell" do |s|    
            s.path = "setup.sh"    
            s.args = ["master"]  
    end
  end

  # config.vm.define "worker-1" do | w |
  #     w.vm.hostname = "worker-1"

  #     w.vm.network "private_network", ip: "192.168.33.14"

  #     w.vm.provider "virtualbox" do |vb|
  #       vb.memory = "1024"
  #       vb.cpus = 1
  #       vb.name = "worker-1"
  #     end

  #     w.vm.provision:shell, path: "setup.sh"

  #     config.vm.provision "shell" do |s|    
  #       s.path = "setup.sh"    
  #       s.args = ["worker"]  
  #     end

  #   end
  # end 

  # config.vm.define "worker-2" do | w |
  #     w.vm.hostname = "worker-2"
  #     w.vm.network "private_network", ip: "192.168.33.15"

  #     w.vm.provider "virtualbox" do |vb|
  #       vb.memory = "1024"
  #       vb.cpus = 1
  #       vb.name = "worker-2"
  #     end
  #     w.vm.provision:shell, path: "k8s-setup-master.sh"
  # end

end
