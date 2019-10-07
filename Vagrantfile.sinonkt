#!/usr/local/bin/env ruby
# -*- mode: ruby -*-
# # vi: set ft=ruby :
# No more configurable params just look for all things from ansible inventory
# ************************ Configurable Params ************************
# $inventory='nbt' 
# *********************************************************************
# 1. groups vars should play their role.
# 2. /etc/hosts.
$abs_root_path=File.dirname(__FILE__)
$inventory_path="inventory"

require 'yaml'
require File.join($abs_root_path, 'libs', 'inifile.rb')
require File.join($abs_root_path, 'libs', 'ansible.rb')

hosts_vars, hosts_ini = load_ansible_inventory($inventory_path)

$vms = hosts_vars
$playbook = 'kubespray/cluster.yml'

# Uniq disk UUID for libvirt
$DISK_UUID = Time.now.utc.to_i
$DRIVER_LETTERS = ('a'..'z').to_a
$COREOS_URL_TEMPLATE = "https://storage.googleapis.com/%s.release.core-os.net/amd64-usr/current/coreos_production_vagrant.json"
$SUPPORTED_OS = {
  "coreos-stable"       => {box: "coreos-stable", user: "core", install_cmd: "dnf", box_url: $COREOS_URL_TEMPLATE % ["stable"]},
  "coreos-alpha"        => {box: "coreos-alpha", user: "core", install_cmd: "dnf", box_url: $COREOS_URL_TEMPLATE % ["alpha"]},
  "coreos-beta"         => {box: "coreos-beta", user: "core", install_cmd: "dnf", box_url: $COREOS_URL_TEMPLATE % ["beta"]},
  "ubuntu1604"          => {box: "generic/ubuntu1605", user: "vagrant", install_cmd: "apt-get"},
  "ubuntu1804"          => {box: "generic/ubuntu1804", user: "vagrant", install_cmd: "apt-get"},
  "centos"              => {box: "centos/7", user: "vagrant", install_cmd: "yum"},
  "centos-bento"        => {box: "bento/centos-7.5", user: "vagrant", install_cmd: "yum"},
  "fedora"              => {box: "fedora/28-cloud-base", user: "vagrant", install_cmd: "dnf"},
  "opensuse"            => {box: "opensuse/openSUSE-42.3-x86_64", user: "vagrant", install_cmd: "zypper"},
  "opensuse-tumbleweed" => {box: "opensuse/openSUSE-Tumbleweed-x86_64", user: "vagrant", install_cmd: "zypper"},
}

if Vagrant.has_plugin?("vagrant-proxyconf")
    $no_proxy = ENV['NO_PROXY'] || ENV['no_proxy'] || "127.0.0.1,localhost"
    $vms.each do |vm_name, vm|
        $no_proxy += ",#{vm["ip"]}"
    end
end

$ansible_user = nil
Vagrant.configure("2") do |config|
  # plugin conflict
  if Vagrant.has_plugin?("vagrant-vbguest") then
    config.vbguest.auto_update = false
  end
  # always use Vagrants insecure key
  config.ssh.insert_key = false
  config.ssh.private_key_path = File.join($abs_root_path, '.ssh', 'insecure_private_key') 
  config.ssh.forward_agent = true

  #################### Loop for each VM ####################
  $vms.each do |vm_name, vm|
    config.vm.define vm_name do |node|
      node.vm.hostname = vm_name
      #################### Configure OS & Deployment User ####################
      os = $SUPPORTED_OS[vm["vagrant"]["os"]]
      user = os[:user]
      $ansible_user = os[:user]
      node.vm.box = os[:box]
      if os.has_key? :box_url
        node.vm.box_url = os[:box_url]
      end
      node.ssh.username = user
      ########################################################################
      ########################## Configure Disk ##############################
      if (vm["vagrant"]["disk"]["override_disk_size"])
        unless Vagrant.has_plugin?("vagrant-disksize")
          system "vagrant plugin install vagrant-disksize"
        end
        config.disksize.size = vm["vagrant"]["disk"]["disk_size"]
      end

      if vm["vagrant"]["disks"]
        # Libvirt
        node.vm.provider :libvirt do |lv|
          # always make /dev/sd{a/b/c} so that CI can ensure that
          # virtualbox and libvirt will have the same devices to use for OSDs
          (1..vm["vagrant"]["disks"]["num_disks"]).each do |d|
            lv.storage :file, :device => "hd#{$DRIVER_LETTERS[d]}", :path => "disk-#{vm_name}-#{d}-#{$DISK_UUID}.disk", :size => vm["vagrant"]["disks"]["disk_size"], :bus => "ide"
          end
        end
      end
      ########################################################################
      ########################## Configure Proxy #############################
      if Vagrant.has_plugin?("vagrant-proxyconf")
        node.proxy.http     = ENV['HTTP_PROXY'] || ENV['http_proxy'] || ""
        node.proxy.https    = ENV['HTTPS_PROXY'] || ENV['https_proxy'] ||  ""
        node.proxy.no_proxy = $no_proxy
      end
      ########################################################################
      ####################### Configure by Provider ##########################
      ["vmware_fusion", "vmware_workstation"].each do |vmware|
        node.vm.provider vmware do |v|
          v.vmx['memsize'] = vm["vagrant"]["memory"]
          v.vmx['numvcpus'] = vm["vagrant"]["cpus"]
        end
      end

      node.vm.provider :virtualbox do |vb|
        vb.memory = vm["vagrant"]["memory"]
        vb.cpus = vm["vagrant"]["cpus"]
        vb.gui = vm["vagrant"]["gui"]
        vb.linked_clone = true
        vb.customize ["modifyvm", :id, "--vram", "8"] # ubuntu defaults to 256 MB which is a waste of precious RAM
      end

      node.vm.provider :libvirt do |lv|
        lv.memory = vm["vagrant"]["memory"]
        lv.cpus = vm["vagrant"]["cpus"]
        lv.default_prefix = 'kubespray'
        # Fix kernel panic on fedora 28
        if $os == "fedora"
          lv.cpu_mode = "host-passthrough"
        end
      end
      ########################################################################
      ############### Configure Network & Port forwarding ####################
      node.vm.network :private_network, ip: vm['ip']

      if vm['vagrant']['expose_docker_tcp']
        node.vm.network "forwarded_port", guest: 2375, host: vm['vagrant']['expose_docker_tcp'], auto_correct: true
      end

      if vm['vagrant']['forwarded_ports']
        vm['vagrant']['forwarded_ports'].each do |guest, host|
          node.vm.network "forwarded_port", guest: guest, host: host, auto_correct: true
        end
      end
      ########################################################################
      ##################### Configure Synced Folder ##########################
      node.vm.synced_folder ".", "/vagrant", disabled: false, type: "rsync", rsync__args: ['--verbose', '--archive', '--no-links', '--delete', '-z'], rsync__exclude: ['.git','venv']
      if vm['vagrant']['shared_folders']
        vm['vagrant']['shared_folders'].each do |src, dst|
          node.vm.synced_folder src, dst, type: "rsync", rsync__args: ['--verbose', '--archive', '--no-links', '--delete', '-z']
        end
      end
      ########################################################################

      # Disable swap for each vm
      node.vm.provision "shell", inline: "swapoff -a"

      node.vm.provision "file", source: "~/.vagrant.d/insecure_private_key", destination: "/home/#{user}/.ssh/id_rsa"
      node.vm.provision "shell", inline: "ssh-keygen -y -f /home/#{user}/.ssh/id_rsa > /home/#{user}/.ssh/id_rsa.pub"
      node.vm.provision "shell", inline: "chmod 600 /home/#{user}/.ssh/id_rsa*"
      node.vm.provision "shell", inline: "chown #{user}:#{user} /home/#{user}/.ssh/id_rsa*"
      node.vm.provision "shell", inline: "cat /home/#{user}/.ssh/id_rsa.pub >> /home/#{user}/.ssh/authorized_keys"


      # Only execute the Ansible provisioner once, when all the machines are up and ready.
      # puts "#{vm_name} == #{$vms.keys[-1]}"
      if vm_name == $vms.keys[-1]
        # Fixed ansible get stuck while installing ansible at guest machine. provision only last node.
        node.vm.provision "shell", inline: "#{os[:install_cmd]} install -y git python-pip python-netaddr"
        node.vm.provision "shell", inline: "curl https://bootstrap.pypa.io/get-pip.py -o get-pip.py && python get-pip.py"
        node.vm.provision "shell", inline: "pip install git+https://github.com/ansible/ansible.git@stable-2.8"

        node.vm.provision "ansible_local" do |ansible|
          ansible.playbook = $playbook
          $ansible_inventory_path = File.join($inventory_path, "hosts.ini")
          if File.exist?($ansible_inventory_path)
            ansible.inventory_path = $ansible_inventory_path
          end
          ansible.become = true
          ansible.limit = "all"
          ansible.install = false

          # puts $ansible_user
          ansible.raw_arguments = ["--forks=#{$vms.length}", "--flush-cache", "-e ansible_become_pass=#{$ansible_user}"]
          # ansible.host_vars = $vms
          # #ansible.tags = ['download']
          groups = get_ansible_groups(hosts_ini)
          # ansible.groups = groups
        end
        
        node.vm.provision "shell", inline: "sudo mkdir -p /home/#{user}/.kube" 
        node.vm.provision "shell", inline: "sudo cp /etc/kubernetes/admin.conf /home/#{user}/.kube/config"
        node.vm.provision "shell", inline: "sudo chown -R #{user}:#{user} /home/#{user}/.kube/config"
      end
    end
  end
end
