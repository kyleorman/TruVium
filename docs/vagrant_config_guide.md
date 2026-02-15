# TruVium Vagrant Configuration Guide

This guide provides a comprehensive overview of the configuration options available for Vagrant with VirtualBox. It explains each setting in the `vagrant_config.json` file that can be used to customize the TruVium virtual machine's behavior, performance, and features.

## Configuration Structure

The configuration is stored in a JSON file, typically named `vagrant_config.json`. Each section controls different aspects of the virtual machine, from basic resources to advanced virtualization features.

## Configuration Options

### Base Box Configuration
```json
{
  "vm_box": "archlinux/archlinux",        // The base Vagrant box to use
  "vm_box_version": "20241001.267073",    // Specific version of the box
  "box_check_update": true,               // Whether to check for box updates
  "vm_hostname": "dev-env",               // Hostname of the VM
  "primary_disk_size": "20GB"             // Primary VM disk size
```

### Resource Allocation
```json
  "vm_memory": "4096",                    // RAM allocation in MB (4GB)
  "vm_cpus": 5,                           // Number of CPU cores
```

### Display/GUI Settings
```json
  "vb_gui": false,                        // Whether to show VM window
  "graphics_controller": "VBoxSVGA",      // Graphics controller type (VBoxSVGA, VMSVGA, VBoxVGA)
  
  "vb_display": {
    "video_memory": 32,                   // Video memory in MB
    "3d_acceleration": true,              // Enable/disable 3D acceleration
    "remote_display": false,              // VirtualBox Remote Display (VRDE)
    "remote_display_port": 3389,          // Port for remote display
    "monitor_count": 1,                   // Number of virtual monitors
    "custom_resolution": "1920x1080x32"  // Optional custom resolution
  },
```

### Storage Configuration
```json
  "storage": {
    "additional_disks": [],               // Array for additional storage disks
    "controller": "SATA"                  // Storage controller type
  },
```

### Virtualization Performance Settings
```json
  "vb_performance": {
    "pae": true,                          // Physical Address Extension
    "nested_paging": true,                // Nested paging for better performance
    "large_pages": true,                  // Large memory pages support
    "vtx_vpid": true,                     // Intel VT-x VPID support
    "hw_virtualization": true,            // Hardware virtualization
    "io_apic": true,                      // I/O APIC support
    "page_fusion": true                   // Memory page fusion
  },
```

### Clipboard/Integration
```json
  "vb_clipboard": "bidirectional",        // Clipboard sharing (disabled, hosttoguest, guesttohost, bidirectional)
```

### SSH Configuration
```json
  "ssh_forward_x11": true,                // X11 forwarding for GUI apps
  "ssh_insert_key": false,                // Whether to insert a new SSH key
  "ssh_username": "vagrant",             // Optional SSH username override
  "ssh_private_key_path": "~/.ssh/id_rsa" // Optional private key path
```

### Port Forwarding
```json
  "forward_jupyter_port": false,          // Specific for Jupyter notebook
  "port_forwarding": [],                  // Array for custom port forwards
```

### Shared Folders
```json
  "synced_folders": [
    {
      "guest": "/home/vagrant/TruWork",   // Path in VM
      "host": "~/TruWork",                // Path on host
      "create": true                      // Create if doesn't exist
    }
  ],
```

### Provisioning
```json
  "provision": [
    {
      "type": "shell",                    // Type of provisioner
      "path": "vagrant-scripts/vagrant_setup_arch.sh"  // Script to run
    }
  ],
```

### Network Configuration
```json
  "networks": [
    {
      "type": "private_network",          // Network type
      "dhcp": true                        // Use DHCP for IP assignment
    }
  ],
```

### Additional Settings
```json
  "environment_variables": {},            // Environment variables to set
  "user_shell": "zsh",                   // Default shell (bash or zsh)
  "swap_size": "4G",                     // Initial swap size
  "default_swap_size": "1G"              // Post-provision swap size
}
```

## Common Configuration Examples
> **Note**: Json does not use comments, so remove them if you plan on using these configuration options.

## 1. Headless CLI Environment
Optimized for command-line work, development, and servers.

```json
{
  "vm_box": "archlinux/archlinux",
  "vm_box_version": "20241001.267073",
  "box_check_update": true,
  "vm_hostname": "cli-dev",
  
  // Minimal resources for CLI work
  "vm_memory": "2048",        // 2GB RAM is usually sufficient
  "vm_cpus": 2,              // 2 cores for basic operations
  
  // Disable GUI
  "vb_gui": false,
  "graphics_controller": "VMSVGA",

  // Minimal display settings (for emergency GUI access)
  "vb_display": {
    "video_memory": 12,       // Minimum VRAM
    "3d_acceleration": false,
    "remote_display": false,
    "monitor_count": 1
  },
  
  // Optimized performance settings
  "vb_performance": {
    "pae": true,
    "nested_paging": true,
    "hw_virtualization": true,
    "io_apic": true,
    "page_fusion": false      // Not needed for single VM
  },
  
  // Basic clipboard for copy/paste
  "vb_clipboard": "bidirectional",
  
  // SSH settings
  "ssh_forward_x11": false,   // No X11 needed
  "ssh_insert_key": false,
  
  // No Jupyter needed
  "forward_jupyter_port": false,
  
  // Minimal network setup
  "networks": [
    {
      "type": "private_network",
      "dhcp": true
    }
  ],
  
  // Basic shell setup
  "user_shell": "bash",       // bash is sufficient for CLI but I still prefer zsh
  
  // Conservative swap
  "swap_size": "1G",
  "default_swap_size": "1G"
}
```

## 2. GUI Desktop Environment
Balanced configuration for desktop usage with GUI applications.

```json
{
  "vm_box": "archlinux/archlinux",
  "vm_box_version": "20241001.267073",
  "box_check_update": true,
  "vm_hostname": "gui-dev",
  
  // Comfortable resources for GUI work
  "vm_memory": "4096",        // 4GB RAM for desktop environment
  "vm_cpus": 4,              // 4 cores for better responsiveness
  
  // Enable GUI
  "vb_gui": true,
  "graphics_controller": "VBoxSVGA",  // Best for modern systems
  
  // Display settings for desktop use
  "vb_display": {
    "video_memory": 128,      // Good for modern desktop
    "3d_acceleration": true,  // Enable for better performance
    "remote_display": false,
    "monitor_count": 1
  },
  
  // Storage configuration
  "storage": {
    "additional_disks": [],
    "controller": "SATA"
  },
  
  // Performance settings for desktop use
  "vb_performance": {
    "pae": true,
    "nested_paging": true,
    "large_pages": true,
    "vtx_vpid": true,
    "hw_virtualization": true,
    "io_apic": true,
    "page_fusion": false      // Not needed for single VM
  },
  
  // Full clipboard integration
  "vb_clipboard": "bidirectional",
  
  // X11 forwarding for GUI apps
  "ssh_forward_x11": true,
  "ssh_insert_key": false,
  
  // No Jupyter by default
  "forward_jupyter_port": false,
  
  // Network configuration
  "networks": [
    {
      "type": "private_network",
      "dhcp": true
    }
  ],
  
  // Modern shell
  "user_shell": "zsh",
  
  // Generous swap for desktop applications
  "swap_size": "4G",
  "default_swap_size": "2G"
}
```

## Key Differences Explained

1. **Resource Allocation**
   - CLI: Minimal 2GB RAM, 2 CPUs
   - GUI: Comfortable 4GB RAM, 4 CPUs for smoother operation

2. **Display Settings**
   - CLI: Minimal 12MB VRAM, no 3D
   - GUI: 128MB VRAM with 3D acceleration

3. **Performance Features**
   - CLI: Basic virtualization features
   - GUI: Additional features like large pages and VPID

4. **Shell Choice**
   - CLI: Basic bash shell
   - GUI: Modern zsh with better interactive features

5. **Swap Configuration**
   - CLI: Conservative 1G swap
   - GUI: Larger swap for desktop applications

6. **X11 Forwarding**
   - CLI: Disabled
   - GUI: Enabled for graphical applications

## Notes

1. **Scaling Resources**
   - Memory and CPU can be adjusted based on host capabilities
   - Video memory can be increased for multiple monitors

2. **Optional Enhancements**
   - Add port forwarding as needed
   - Configure shared folders based on workflow
   - Adjust swap size based on memory usage patterns

3. **Performance Tips**
   - CLI: Focus on I/O and CPU efficiency
   - GUI: Balance between responsiveness and resource usage

## Notes on Graphics Controllers

- **VBoxSVGA**: Modern default choice, good balance of features and performance
- **VMSVGA**: VMware compatible, better for some specific workloads
- **VBoxVGA**: Legacy option, use only for compatibility with older systems

## Notes on Performance Settings

- Enable `nested_paging` for better performance with hardware virtualization
- Use `large_pages` for better memory performance with large RAM allocations
- Enable `page_fusion` to save memory when running multiple similar VMs

## Network Types

- `private_network`: Isolated network between host and VMs
- `public_network`: Bridged networking, VM appears on same network as host
- `forwarded_port`: Port forwarding for specific services

## Storage Controllers

- `SATA`: Modern standard, good performance
- `IDE`: Legacy compatibility
- `SCSI`: Advanced features, typically for server workloads
- `NVMe`: Highest performance, requires compatible guest OS
