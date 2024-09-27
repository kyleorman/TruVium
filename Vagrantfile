require 'json'

Vagrant.configure("2") do |config|
  # Load the configuration from the JSON file
  config_file = "vagrant_config.json"
  if File.exist?(config_file)
    settings = JSON.parse(File.read(config_file))
  else
    settings = {}
    puts "Warning: #{config_file} not found. Default settings will be used."
  end

  # VM box configuration
  config.vm.box = settings['vm_box'] || "ubuntu/jammy64" # Ubuntu 22.04
  config.vm.box_version = settings['vm_box_version'] if settings.key?('vm_box_version')
  config.vm.box_check_update = settings.fetch('box_check_update', true)

  # Assign a hostname
  config.vm.hostname = settings['vm_hostname'] || "dev-env"

  # Configure networking
  if settings.key?('networks')
    settings['networks'].each do |network|
      network_type = network['type']
      options = network.reject { |k, _| k == 'type' }.transform_keys(&:to_sym)

      # Ensure DHCP is handled properly
      if options[:dhcp] == true
        config.vm.network network_type, type: "dhcp"
      else
        config.vm.network network_type, **options
      end
    end
  else
    # Default network configuration
    config.vm.network "private_network", type: "dhcp"
  end

  # Configure port forwarding
  if settings.key?('port_forwarding')
    settings['port_forwarding'].each do |pf|
      config.vm.network "forwarded_port", guest: pf['guest'], host: pf['host'], protocol: pf['protocol'] || "tcp"
    end
  elsif settings.key?('forward_jupyter_port') && settings['forward_jupyter_port']
    # Original Jupyter port forwarding
    config.vm.network "forwarded_port", guest: 8888, host: 8888
  end

  # Enable X11 forwarding for GUI applications
  config.ssh.forward_x11 = settings.fetch('ssh_forward_x11', true)
  config.ssh.insert_key = settings.fetch('ssh_insert_key', false)
  config.ssh.username = settings['ssh_username'] if settings.key?('ssh_username')
  config.ssh.private_key_path = settings['ssh_private_key_path'] if settings.key?('ssh_private_key_path')

  # Provisioning scripts
  if settings.key?('provision')
    settings['provision'].each do |script|
      if script['type'] == 'shell'
        config.vm.provision "shell" do |s|
          s.path = script['path'] if script['path']
          s.inline = script['inline'] if script['inline']
          s.args = script['args'] if script['args']
          s.env = script['env'] if script['env']
        end
      elsif script['type'] == 'ansible'
        config.vm.provision "ansible" do |ansible|
          ansible.playbook = script['playbook']
          ansible.extra_vars = script['extra_vars'] if script.key?('extra_vars')
        end
      end
    end
  else
    # Default provisioning with vagrant_setup.sh script
    config.vm.provision "shell", path: "vagrant_setup.sh"
  end

  # Configure synced folders
  if settings.key?('synced_folders')
    settings['synced_folders'].each do |folder|
      # Dynamically expand the '~' in host paths to the home directory
      host_path = folder['host'].gsub("~", ENV['HOME'])
      config.vm.synced_folder host_path, folder['guest'], create: folder['create']
    end
  end

  # Customize VM resources (headless setup)
  vm_memory = settings['vm_memory'] || "4096"
  vm_cpus = settings['vm_cpus'] || 2
  config.vm.provider "virtualbox" do |vb|
    vb.memory = vm_memory    # Adjust memory
    vb.cpus = vm_cpus        # Adjust number of CPUs
    vb.gui = settings.fetch('vb_gui', false)  # Enable or disable GUI mode
    vb.customize ["modifyvm", :id, "--clipboard", settings.fetch('vb_clipboard', 'disabled')]
    vb.customize ["modifyvm", :id, "--graphicscontroller", settings["graphics_controller"]]
  end

  # Determine the shell configuration file based on the user's shell
  user_shell = settings['user_shell'] || 'bash'
  shell_rc = case user_shell
             when 'bash'
               '.bashrc'
             when 'zsh'
               '.zshrc'
             else
               '.bashrc' # default to .bashrc if unknown shell
             end

  # Install zsh and set as default shell if user_shell is zsh
  if user_shell == 'zsh'
    config.vm.provision "shell", inline: <<-SHELL
      if ! command -v zsh &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y zsh
      fi
      # Change default shell to zsh
      sudo chsh -s $(which zsh) vagrant
      # Ensure .zshrc exists
      touch /home/vagrant/.zshrc
      chown vagrant:vagrant /home/vagrant/.zshrc
    SHELL
  end

  # Environment variables
  if settings.key?('environment_variables')
    settings['environment_variables'].each do |key, value|
      config.vm.provision "shell", inline: <<-SHELL
        echo 'export #{key}="#{value}"' >> /home/vagrant/#{shell_rc}
      SHELL
    end
  end

  # Post-up message
  if settings.key?('post_up_message')
    config.vm.post_up_message = settings['post_up_message']
  else
    # Default post-up message
    if settings.key?('forward_jupyter_port') && settings['forward_jupyter_port']
      config.vm.post_up_message = "Port forwarding for Jupyter is enabled on port 8888."
    else
      config.vm.post_up_message = "Port forwarding for Jupyter is disabled."
    end
  end
end
