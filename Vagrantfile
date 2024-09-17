Vagrant.configure("2") do |config|
  # Define the base box
  config.vm.box = "ubuntu/jammy64" # Ubuntu 22.04

  # Assign a hostname
  config.vm.hostname = "dev-env"

  # Configure networking
  config.vm.network "private_network", type: "dhcp"

  # Enable X11 forwarding for GUI applications
  config.ssh.forward_x11 = true

  # Provisioning with adjusted_setup.sh script
  config.vm.provision "shell", path: "vagrant_setup.sh"

  # Provisioning with git_setup.sh script
  config.vm.provision "shell" do |s|
    s.inline = "cd /vagrant && bash git_setup.sh --config-file git_setup.conf --non-interactive"
    s.privileged = false
  end

  # Customize VM resources (headless setup)
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"    # Adjust memory
    vb.cpus = 2           # Adjust number of CPUs
    vb.gui = false        # Disable full GUI (keep headless)
  end
end

