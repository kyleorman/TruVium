Vagrant.configure("2") do |config|
  require 'json'
  require 'fileutils'

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
  config.vm.box = settings['vm_box'] || "archlinux/archlinux" # Default to Arch
  config.vm.box_version = settings['vm_box_version'] if settings.key?('vm_box_version')
  config.vm.box_check_update = settings.fetch('box_check_update', true)
  primary_disk_size = settings.fetch('primary_disk_size', '20GB')

  # Configure the primary disk with the user-defined or default size
  config.vm.disk :disk, name: "primary", size: primary_disk_size, primary: true

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
      SWAPDIR=/swap
      SWAPFILE="$SWAPDIR/swapfile"
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

      # Create swap directory if it doesn't exist
      mkdir -p "$SWAPDIR"

      # Safely disable existing swap
      if [ -f "$SWAPFILE" ]; then
        echo "Disabling existing swap..."
        swapoff "$SWAPFILE" || true
        rm -f "$SWAPFILE"
      fi
      # Also check and disable legacy swap location
      if [ -f "/swapfile" ]; then
        echo "Disabling legacy swap..."
        swapoff "/swapfile" || true
        rm -f "/swapfile"
      fi
      # Clean up any existing swap entries
      sed -i '/swap.*swap/d' /etc/fstab

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
	  # Backup current mirrorlist
	  cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
	  # Update mirrors using reflector
	  pacman -Sy --noconfirm --needed reflector archlinux-keyring
	  reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
	  # Update entire system in one go with overwrite handling
	  pacman -Syu --noconfirm --overwrite '/usr/share/man/*/man1/kill.1.gz'
	  # Install required tools
	  pacman -S --noconfirm --needed util-linux btrfs-progs
	else
	  echo "Unsupported OS: $OS"
	  exit 1
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
      SWAPDIR=/swap
      SWAPFILE="$SWAPDIR/swapfile"
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

      # Create swap directory if it doesn't exist
      mkdir -p "$SWAPDIR"

      # Safely disable existing swap
      if [ -f "$SWAPFILE" ]; then
        echo "Disabling existing swap..."
        swapoff "$SWAPFILE" || true
        rm -f "$SWAPFILE"
      fi
      # Also check and disable legacy swap location
      if [ -f "/swapfile" ]; then
        echo "Disabling legacy swap..."
        swapoff "/swapfile" || true
        rm -f "/swapfile"
      fi
      # Clean up any existing swap entries
      sed -i '/swap.*swap/d' /etc/fstab

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

  # Enhanced VirtualBox Provider Configuration
  config.vm.provider "virtualbox" do |vb|
    # Basic Resources
    vb.memory = settings['vm_memory'] || "4096"
    vb.cpus = settings['vm_cpus'] || 2
    vb.gui = settings.fetch('vb_gui', false)

	# Display Settings
	if settings.key?('vb_display')
	  display = settings['vb_display']
	  vb.customize ["modifyvm", :id, "--vram", display.fetch('video_memory', 128)]
	  vb.customize ["modifyvm", :id, "--accelerate3d", display.fetch('3d_acceleration', true) ? "on" : "off"]
	  vb.customize ["modifyvm", :id, "--graphicscontroller", settings.fetch("graphics_controller", "VBoxSVGA")]

	  # Set custom resolution if specified
	  if display['custom_resolution']
	    vb.customize ["setextradata", :id, "CustomVideoMode1", display['custom_resolution']]
	  end	  
	  
	  if display['remote_display']
		vb.customize ["modifyvm", :id, "--vrde", "on"]
		vb.customize ["modifyvm", :id, "--vrdeport", display.fetch('remote_display_port', 3389)]
	  else
		vb.customize ["modifyvm", :id, "--vrde", "off"]
	  end
	  
	  vb.customize ["modifyvm", :id, "--monitorcount", display.fetch('monitor_count', 1)]
	end

    # Performance Settings
    if settings.key?('vb_performance')
      perf = settings['vb_performance']
      vb.customize ["modifyvm", :id, "--pae", perf.fetch('pae', true) ? "on" : "off"]
      vb.customize ["modifyvm", :id, "--nestedpaging", perf.fetch('nested_paging', true) ? "on" : "off"]
      vb.customize ["modifyvm", :id, "--largepages", perf.fetch('large_pages', true) ? "on" : "off"]
      vb.customize ["modifyvm", :id, "--vtxvpid", perf.fetch('vtx_vpid', true) ? "on" : "off"]
      vb.customize ["modifyvm", :id, "--hwvirtex", perf.fetch('hw_virtualization', true) ? "on" : "off"]
      vb.customize ["modifyvm", :id, "--ioapic", perf.fetch('io_apic', true) ? "on" : "off"]
      vb.customize ["modifyvm", :id, "--pagefusion", perf.fetch('page_fusion', true) ? "on" : "off"]
    end

    # Storage Configuration
    if settings.key?('storage')
      storage = settings['storage']
      
      # Add additional disks
      if storage.key?('additional_disks')
        # Create vm-disks directory if it doesn't exist
        FileUtils.mkdir_p(File.join(base_path, "vm-disks"))
        
        storage['additional_disks'].each_with_index do |disk, index|
          disk_path = File.join(base_path, "vm-disks", "#{disk['name']}.#{disk['format'] || 'vdi'}")
          
          unless File.exist?(disk_path)
            vb.customize ['createhd', 
              '--filename', disk_path,
              '--size', disk['size'].to_s.gsub(/[^\d]/, ''),
              '--format', disk['format'] || 'vdi']
          end
          
          vb.customize ['storageattach', :id,
            '--storagectl', storage['controller'] || 'SATA',
            '--port', disk['port'] || (index + 1),
            '--device', 0,
            '--type', disk['type'] || 'hdd',
            '--medium', disk_path]
        end
      end
    end

    # Other VirtualBox-specific settings
    vb.customize ["modifyvm", :id, "--clipboard", settings.fetch('vb_clipboard', 'disabled')]
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

#   # Configure post-up message
#   config.vm.post_up_message = if settings.key?('post_up_message')
#     settings['post_up_message']
#   elsif settings.key?('forward_jupyter_port') && settings['forward_jupyter_port']
#     "Port forwarding for Jupyter is enabled on port 8888."
#   else
#     "Port forwarding for Jupyter is disabled."
#   end
end
