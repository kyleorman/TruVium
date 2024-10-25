Vagrant.configure("2") do |config|
  require 'json'

  # Get the base path of the Vagrantfile
  base_path = File.dirname(__FILE__)

  # Load the configuration from the JSON file
  config_file = File.join(base_path, "vagrant-config", "vagrant_config.json")
  if File.exist?(config_file)
    settings = JSON.parse(File.read(config_file))
  else
    settings = {}
    puts "Warning: #{config_file} not found. Default settings will be used."
  end

  # VM box configuration
  config.vm.box = settings['vm_box'] || "ubuntu/jammy64" # Default to Ubuntu 22.04
  config.vm.box_version = settings['vm_box_version'] if settings.key?('vm_box_version')
  config.vm.box_check_update = settings.fetch('box_check_update', true)

  # Assign a hostname
  config.vm.hostname = settings['vm_hostname'] || "dev-env"

  # Configure networking
  if settings.key?('networks')
    settings['networks'].each do |network|
      network_type = network['type']
      options = network.reject { |k, _| k == 'type' }.transform_keys(&:to_sym)

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
    config.vm.network "forwarded_port", guest: 8888, host: 8888
  end

  # Enable X11 forwarding for GUI applications
  config.ssh.forward_x11 = settings.fetch('ssh_forward_x11', true)
  config.ssh.insert_key = settings.fetch('ssh_insert_key', false)
  config.ssh.username = settings['ssh_username'] if settings.key?('ssh_username')
  config.ssh.private_key_path = settings['ssh_private_key_path'] if settings.key?('ssh_private_key_path')

  # Configure initial swap size before provisioning
  if settings.key?('swap_size')
    swap_size = settings['swap_size']
    config.vm.provision "shell", privileged: true, name: "Configure Initial Swap Space", inline: <<-SHELL
      set -e  # Exit on any error
      SWAPFILE=/swapfile
      SWAPSIZE=#{swap_size}

      # Detect OS
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
      else
        OS=$(uname -s)
      fi
      echo "Detected OS: $OS"

      echo "Configuring swap space to $SWAPSIZE..."

      # Safely disable existing swap
      if [ -f "$SWAPFILE" ]; then
        echo "Disabling existing swap..."
        swapoff "$SWAPFILE" || true
        rm -f "$SWAPFILE"
        sed -i '/\\swapfile/d' /etc/fstab
      fi

      # Extract size and unit
      SIZE=$(echo "$SWAPSIZE" | sed 's/[^0-9]*//g')
      UNIT=$(echo "$SWAPSIZE" | sed 's/[0-9]*//g' | tr '[:lower:]' '[:upper:]')

      # Convert to MB based on unit
      case "$UNIT" in
        "G")
          SIZE=$((SIZE * 1024))
          ;;
        "M")
          SIZE=$SIZE
          ;;
        "T")
          SIZE=$((SIZE * 1024 * 1024))
          ;;
        *)
          echo "Invalid unit: $UNIT. Using MB."
          ;;
      esac

      # Install necessary tools based on OS
      if [ "$OS" = "ubuntu" ]; then
        apt-get update -y
        apt-get install -y util-linux btrfs-progs
      elif [ "$OS" = "arch" ]; then
        pacman -Sy --noconfirm util-linux btrfs-progs
      fi

      # Check filesystem type
      FS_TYPE=$(stat -f -c %T /)
      echo "Detected filesystem: $FS_TYPE"

      if [ "$FS_TYPE" = "btrfs" ]; then
        echo "Using Btrfs-specific swap setup..."
        
        # Create a properly aligned swap file
        truncate -s 0 "$SWAPFILE"
        chattr +C "$SWAPFILE" 2>/dev/null || true  # Disable CoW, don't fail if not supported
        fallocate -l "${SIZE}M" "$SWAPFILE"
        
        # Set proper permissions
        chmod 600 "$SWAPFILE"
        
        # Get page size and offset for Btrfs
        PAGESIZE=$(getconf PAGESIZE)
        
        if command -v filefrag >/dev/null 2>&1; then
          OFFSET=$(filefrag -v "$SWAPFILE" | awk '{ if($1==0) print $4 }' | cut -d'.' -f1)
          if [ -n "$OFFSET" ]; then
            echo "Btrfs swap file created with offset $OFFSET and pagesize $PAGESIZE"
            # Initialize and enable swap with offset
            mkswap -f "$SWAPFILE"
            swapon "$SWAPFILE" --offset "$OFFSET"
            # Update /etc/fstab with offset
            echo "$SWAPFILE none swap sw,offset=$OFFSET 0 0" >> /etc/fstab
          else
            echo "Could not determine offset, falling back to standard swap setup"
            mkswap "$SWAPFILE"
            swapon "$SWAPFILE"
            echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
          fi
        else
          echo "filefrag not available, using standard swap setup"
          mkswap "$SWAPFILE"
          swapon "$SWAPFILE"
          echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
        fi
      else
        echo "Using standard swap setup for ${FS_TYPE}..."
        
        # Create swap file
        dd if=/dev/zero of="$SWAPFILE" bs=1M count="$SIZE" status=progress
        chmod 600 "$SWAPFILE"
        mkswap "$SWAPFILE"
        swapon "$SWAPFILE"
        echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
      fi

      # Verify swap is active
      echo "Verifying swap configuration..."
      if swapon --show | grep -q "$SWAPFILE"; then
        echo "Swap configuration successful"
        free -h
      else
        echo "Swap configuration failed"
        swapon -s
        ls -l "$SWAPFILE"
        dmesg | tail -n 20
        exit 1
      fi
    SHELL
  end
  
  # Provisioning scripts
  if settings.key?('provision')
    settings['provision'].each do |script|
      if script['type'] == 'shell'
        config.vm.provision "shell" do |s|
          s.path = File.join(base_path, script['path']) if script['path']
          s.inline = script['inline'] if script['inline']
          s.args = script['args'] if script['args']
          s.env = script['env'] if script['env']
        end
      elsif script['type'] == 'ansible'
        config.vm.provision "ansible" do |ansible|
          ansible.playbook = File.join(base_path, script['playbook'])
          ansible.extra_vars = script['extra_vars'] if script.key?('extra_vars')
        end
      end
    end
  else
    # Default provisioning with vagrant_setup_arch.sh script
    config.vm.provision "shell", path: File.join(base_path, "vagrant-scripts", "vagrant_setup_arch.sh")
  end

  # Reset swap size after provisioning
  if settings.key?('default_swap_size')
    default_swap_size = settings['default_swap_size']
    config.vm.provision "shell", privileged: true, name: "Reset Swap Size", run: "always", inline: <<-SHELL
      set -e  # Exit on any error
      SWAPFILE=/swapfile
      SWAPSIZE=#{default_swap_size}

      # Detect OS
      if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
      else
        OS=$(uname -s)
      fi
      echo "Detected OS: $OS"

      echo "Resetting swap space to $SWAPSIZE..."

      # Safely disable existing swap
      if [ -f "$SWAPFILE" ]; then
        echo "Disabling existing swap..."
        swapoff "$SWAPFILE" || true
        rm -f "$SWAPFILE"
        sed -i '/\\swapfile/d' /etc/fstab
      fi

      # Extract size and unit
      SIZE=$(echo "$SWAPSIZE" | sed 's/[^0-9]*//g')
      UNIT=$(echo "$SWAPSIZE" | sed 's/[0-9]*//g' | tr '[:lower:]' '[:upper:]')

      # Convert to MB based on unit
      case "$UNIT" in
        "G")
          SIZE=$((SIZE * 1024))
          ;;
        "M")
          SIZE=$SIZE
          ;;
        "T")
          SIZE=$((SIZE * 1024 * 1024))
          ;;
        *)
          echo "Invalid unit: $UNIT. Using MB."
          ;;
      esac

      # Install necessary tools based on OS
      if [ "$OS" = "ubuntu" ]; then
        apt-get update -y
        apt-get install -y util-linux btrfs-progs
      elif [ "$OS" = "arch" ]; then
        pacman -Sy --noconfirm util-linux btrfs-progs
      fi

      # Check filesystem type
      FS_TYPE=$(stat -f -c %T /)
      echo "Detected filesystem: $FS_TYPE"

      if [ "$FS_TYPE" = "btrfs" ]; then
        echo "Using Btrfs-specific swap setup..."
        
        # Create a properly aligned swap file
        truncate -s 0 "$SWAPFILE"
        chattr +C "$SWAPFILE" 2>/dev/null || true  # Disable CoW, don't fail if not supported
        fallocate -l "${SIZE}M" "$SWAPFILE"
        
        # Set proper permissions
        chmod 600 "$SWAPFILE"
        
        # Get page size and offset for Btrfs
        PAGESIZE=$(getconf PAGESIZE)
        
        if command -v filefrag >/dev/null 2>&1; then
          OFFSET=$(filefrag -v "$SWAPFILE" | awk '{ if($1==0) print $4 }' | cut -d'.' -f1)
          if [ -n "$OFFSET" ]; then
            echo "Btrfs swap file created with offset $OFFSET and pagesize $PAGESIZE"
            # Initialize and enable swap with offset
            mkswap -f "$SWAPFILE"
            swapon "$SWAPFILE" --offset "$OFFSET"
            # Update /etc/fstab with offset
            echo "$SWAPFILE none swap sw,offset=$OFFSET 0 0" >> /etc/fstab
          else
            echo "Could not determine offset, falling back to standard swap setup"
            mkswap "$SWAPFILE"
            swapon "$SWAPFILE"
            echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
          fi
        else
          echo "filefrag not available, using standard swap setup"
          mkswap "$SWAPFILE"
          swapon "$SWAPFILE"
          echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
        fi
      else
        echo "Using standard swap setup for ${FS_TYPE}..."
        
        # Create swap file
        dd if=/dev/zero of="$SWAPFILE" bs=1M count="$SIZE" status=progress
        chmod 600 "$SWAPFILE"
        mkswap "$SWAPFILE"
        swapon "$SWAPFILE"
        echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
      fi

      # Verify swap is active
      echo "Verifying swap configuration..."
      if swapon --show | grep -q "$SWAPFILE"; then
        echo "Swap configuration successful"
        free -h
      else
        echo "Swap configuration failed"
        swapon -s
        ls -l "$SWAPFILE"
        dmesg | tail -n 20
        exit 1
      fi
    SHELL
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
    vb.memory = vm_memory
    vb.cpus = vm_cpus
    vb.gui = settings.fetch('vb_gui', false)
    vb.customize ["modifyvm", :id, "--clipboard", settings.fetch('vb_clipboard', 'disabled')]
    vb.customize ["modifyvm", :id, "--graphicscontroller", settings["graphics_controller"]]
  end

  # Determine shell configuration file
  user_shell = settings['user_shell'] || 'bash'
  shell_rc = case user_shell
             when 'bash'
               '.bashrc'
             when 'zsh'
               '.zshrc'
             else
               '.bashrc'
             end

  # Install and configure shell
  if user_shell == 'zsh'
    config.vm.provision "shell", inline: <<-SHELL
      if ! command -v zsh &> /dev/null; then
        if [ -f /etc/arch-release ]; then
          pacman -Sy --noconfirm zsh
        else
          apt-get update && apt-get install -y zsh
        fi
      fi
      chsh -s $(which zsh) vagrant
      touch /home/vagrant/.zshrc
      chown vagrant:vagrant /home/vagrant/.zshrc
    SHELL
  end

  # Configure environment variables
  if settings.key?('environment_variables')
    settings['environment_variables'].each do |key, value|
      config.vm.provision "shell", inline: <<-SHELL
        echo 'export #{key}="#{value}"' >> /home/vagrant/#{shell_rc}
      SHELL
    end
  end

  # Configure post-up message
  config.vm.post_up_message = if settings.key?('post_up_message')
    settings['post_up_message']
  elsif settings.key?('forward_jupyter_port') && settings['forward_jupyter_port']
    "Port forwarding for Jupyter is enabled on port 8888."
  else
    "Port forwarding for Jupyter is disabled."
  end
end
