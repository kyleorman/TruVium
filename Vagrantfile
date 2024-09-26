Vagrant.configure("2") do |config|
  # Define the base box
  config.vm.box = "ubuntu/jammy64" # Ubuntu 22.04

  # Enable port forwarding for Jupyter
  if ARGV.include?("--jupyter")
    config.vm.network "forwarded_port", guest: 8888, host: 8888
    puts "Port forwarding for Jupyter is enabled on port 8888."
  else
    puts "Port forwarding for Jupyter is disabled."
  end

  # Assign a hostname
  config.vm.hostname = "dev-env"

  # Configure networking
  config.vm.network "private_network", type: "dhcp"

  # Enable X11 forwarding for GUI applications
  config.ssh.forward_x11 = true

  # Provisioning with adjusted_setup.sh script
  config.vm.provision "shell", path: "vagrant_setup.sh"

  # Customize VM resources (headless setup)
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"    # Adjust memory
    vb.cpus = 2           # Adjust number of CPUs
    vb.gui = false        # Disable full GUI (keep headless)
  end
end

