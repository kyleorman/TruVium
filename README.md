			████████╗██████╗ ██╗   ██╗██╗   ██╗██╗██╗   ██╗███╗   ███╗
			╚══██╔══╝██╔══██╗██║   ██║██║   ██║██║██║   ██║████╗ ████║
			   ██║   ██████╔╝██║   ██║██║   ██║██║██║   ██║██╔████╔██║
			   ██║   ██╔══██╗██║   ██║╚██╗ ██╔╝██║██║   ██║██║╚██╔╝██║
			   ██║   ██║  ██║╚██████╔╝ ╚████╔╝ ██║╚██████╔╝██║ ╚═╝ ██║
			   ╚═╝   ╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

# HDL Development Environment

## Overview

TruVium is a comprehensive development environment specifically designed for hardware description language (HDL) development and general-purpose programming. It provides a fully automated setup using Vagrant, incorporating best-in-class development tools, editors, and language support. TruVium aims to streamline the HDL development workflow by providing a consistent, reproducible environment across different platforms.

# 🚨 Important Notice

> **Please Note:**
> - TruVium has switched to **Arch** as the default VM OS. Apple Silicon currently has known limitations with the default VirtualBox workflow (see Host Configuration below).
>   The general purpose development environment is more or less stable. Future updates to this part of TruVium will be focused on improving development workflows within the environment.
>   The next step for the overall TruVium project is to create dockerized development tools that can be modularly connected to accomplish custom HDL workflows.
> 
> ### Notable Features Planned for TruVium:
> - **Command Wrapper in Rust:**  
>   A tool to simplify the usage of TruVium commands and enable seamless configuration management.
> - **Dockerized HDL Development Tools:**  
>   Lightweight, containerized tools tailored for HDL-specific development, ensuring minimal system footprint.
> - **HDL Documentation Generation:**  
>   Automating the creation of high-quality documentation for HDL projects.
> - **CI/CD Integration:**  
>   Streamlined continuous integration and deployment workflows to enhance development efficiency.


## Features

### Core Development Environment
- **Automated Setup**: Complete environment configuration using Vagrant, an open-source tool that provides consistent development environments
- **Multi-Editor Support**: Choose between Vim, Neovim, and Emacs, each preconfigured with extensive customization for HDL development
- **Shell Environment**: Zsh shell is set by default. Fully configured Bash shell, Fish shell, and partial support for NuShell are available as alternative options
- **Version Control**: A script to customize git configuration is available and can be filled out and automatically run during the initial setup, or manually any time afterward
- **Terminal Multiplexer**: tmux is configured with automatic session cleanup, tmux sessionizer for project based sessions, and a variety of useful customizations

### Quality of Life CLI Tools
- **fzf**: Advanced fuzzy finder that enables quick search through files, command history, and processes. Integrates with various tools for enhanced navigation
- **eza**: Modern, maintained alternative to `ls` with Git integration, extended attributes, and beautiful color schemes
- **zoxide**: Smarter `cd` using a "frecency" algorithm (frequency + recency) to jump to commonly used locations
- **btop**: Resource monitor providing real-time statistics for CPU, memory, disks, network, and processes with an intuitive interface
- **ripgrep**: Blazing-fast recursive search tool and `grep` alternative that respects gitignore rules and automatically searches hidden files
- **fd**: User-friendly alternative to `find` with smart defaults, colorful output, and parallel command execution
- **bat**: Feature-rich `cat` clone with syntax highlighting, git integration, and automatic paging
- **yazi**: Modern terminal file manager with image preview capabilities, extensive keyboard shortcuts, and plugin support
- **broot**: Modern directory navigation tool that uses a tree structure
- **taskwarrior**: Flexible command-line task management system with tagging, dependencies, and custom reporting
- **timewarrior**: Companion to taskwarrior providing detailed time tracking and reporting capabilities
- **tldr**: Simplified and practical command-line documentation focusing on examples and common use cases
- **cht.sh**: Unified access to the best community-driven documentation and cheat sheets
- **lazygit**: Simple and powerful terminal UI for git operations with interactive staging, diff viewing, and branch management
- **lazydocker**: Terminal UI for docker management providing container stats, logs, and easy execution of common commands
- **lazysql**: Intuitive terminal interface for database operations supporting multiple database types
- **jq**: Lightweight command-line JSON processor for filtering, transforming, and formatting JSON data
- **doxygen**: Professional documentation generator supporting multiple programming languages with cross-referencing and dependency graphs

### HDL Development Tools
- **GHDL**: Comprehensive open-source VHDL simulator supporting multiple IEEE standards (87, 93, 02, 08). Features include:
  - Extensive IEEE standard compliance
  - Integration with GTKWave for waveform visualization
  - Support for vendor-specific libraries
  - Synthesis and formal verification capabilities

- **GTKWave**: Feature-rich waveform viewer for digital simulation results offering:
  - Support for multiple file formats (VCD, LXT, FST)
  - Advanced signal search and filter capabilities
  - Customizable display preferences
  - Tcl/Tk script support for automation

- **Verilator**: High-performance Verilog/SystemVerilog simulator and lint tool providing:
  - Fast compilation to native C++/SystemC
  - Advanced optimization capabilities
  - Extensive linting rules
  - Support for modern SystemVerilog features

- **iVerilog**: IEEE-compliant Verilog simulator featuring:
  - Full IEEE 1364-2005 standard support
  - Integrated synthesis capabilities
  - Comprehensive test bench support
  - Multiple output format support

- **HDL Checker**: Real-time linting and syntax checking tool offering:
  - Multi-language support (VHDL, Verilog, SystemVerilog)
  - Integration with multiple editors
  - Customizable rule sets
  - Project-wide analysis capabilities

- **Verible**: Google's SystemVerilog toolset providing:
  - Style linting with customizable rules
  - Format checking and auto-formatting
  - Static analysis capabilities
  - Syntax-aware code indexing

- **Yosys**: Comprehensive framework for RTL synthesis and verification including:
  - Multiple HDL input format support
  - Extensive optimization capabilities
  - Formal verification tools
  - Technology mapping features

- **klayout**: Advanced layout viewer and editor featuring:
  - Support for multiple layout formats
  - DRC and LVS capabilities
  - Macro development framework
  - Advanced visualization tools

- **kicad**: Complete electronics design automation suite offering:
  - Schematic capture
  - PCB layout
  - 3D visualization
  - Component management

- **OpenROAD** *(optional/manual)*: Integrated chip design flow tool providing:
  - Floor planning
  - Placement optimization
  - Clock tree synthesis
  - Routing capabilities

### Editor Features

#### Vim Custom Configuration
- Airline status line with theme cycling for visual feedback
- Git integration via Fugitive for version control
- Code completion with CoC (Conquer of Completion)
- File fuzzy finding with FZF for rapid navigation
- Syntax checking with ALE (Asynchronous Lint Engine)
- GitHub Copilot integration for AI-assisted coding
- Custom snippet support for common HDL patterns
- Language server protocol integration for advanced code intelligence

#### Neovim
- LazyVim configuration for modern Neovim experience
- https://www.lazyvim.org/
- https://github.com/LazyVim/LazyVim

#### Emacs
- Doom Emacs configuration for structured editing
- https://github.com/doomemacs/doomemacs

### Language Support
- **HDL**: VHDL, Verilog, SystemVerilog for digital design
- **Scripting**: Python, Perl, Shell for automation and tooling
- **Systems**: C, C++ for high-performance applications
- **Documentation**: LaTeX, Markdown for technical documentation
- **Data**: YAML, JSON for configuration and data exchange
- **Web**: HTML, CSS, JavaScript for web development

## Prerequisites

- VirtualBox 7.0 or later: Virtualization platform
- Vagrant 2.4 or later: Development environment manager
- 2GB minimum available RAM
- 20GB minimum free disk space
- Host system supporting virtualization

## Quick Start

1. **Clone the Repository**
   ```bash
   git clone https://github.com/kyleorman/TruVium.git
   cd TruVium
   ```

2. **Start the Environment**
   ```bash
   vagrant up
   ```

3. **Connect to the Environment**
   ```bash
   vagrant ssh
   ```

Additional host terminal commands

**Reload the Environment**
- If you want to force a restart or boot up the environment if it was off (e.g. after the host machine is rebooted)
   ```bash
   vagrant reload
   ```
**Stop the Environment**
   ```bash
   vagrant halt
   ```

**Destroy the Environment**
warning - configurations made after the instance was created will be lost and you will have to spin up a new instance 
   ```bash
   vagrant destroy
   ```

## Usage Notes

### Operating System
- The default configuration uses Arch Linux for the most up to date software versions
- Uses the pacman package manager (sudo pacman -S <package>)
- Access to community provided AUR packages available via yay (yay -S <package>)

## Configuration

### Host Configuration
- Apple Silicon hosts can run VirtualBox 7.x, but TruVium currently uses the `archlinux/archlinux` x86_64 Vagrant box. There is no official ARM64 Arch Vagrant box for this provider, so the default workflow is currently x86 host focused.
- Host terminal configuration can affect some keybindings, colors, and fonts. Using a NerdFont like FiraCode Mono for powerline symbol support is suggested. Additionally, Alacritty is a good cross-platform terminal, but a separate X-server is needed and may require configuration if you are running on Windows or macOS.

### Vagrant Configuration (`vagrant_config.json`)
- Default configuration sets vm_cpus and vm_memory to relatively low values
- If your host computer can support higher settings, they can be set in `vagrant_config.json` -- this may improve setup time and user experience
- Setup time may also be improved by commenting out unnecessary installs within `vagrant_setup_arch.sh` in `/TruVium/vagrant-scripts`

```json
{
  "vm_box": "archlinux/archlinux",
  "vm_box_version": "20241001.267073",
  "box_check_update": true,
  "vm_hostname": "dev-env",
  "vm_memory": "4096",
  "vm_cpus": 4,
  "vb_gui": false,
  "graphics_controller": "Vboxsvga",
  "primary_disk_size": "20GB"
}
```

### Git Profile Setup
- Fill out `git_setup_example.conf` in `/TruVium/templates`, rename file to git_setup.conf, and place in the `/TruVium/vagrant-config` directory
- It will be applied during `vagrant up`
- Alternatively, run with command:
  ```bash
  ./git_setup.sh --config-file git_setup.conf --non-interactive
  ```
  in the `/vagrant/vagrant-scripts` within the VM
- You may also run the script directly:
  ```bash
  ./git_setup.sh
  ```
  and choose options interactively
- The setup script works on host computers with Chocolatey (Windows), Homebrew (macOS), or natively on most Linux distributions

### Port Forwarding
- To enable Jupyter Notebook access edit `vagrant_config.json` like so:
```json
{
  "forward_jupyter_port": true,
  "port_forwarding": [
    { "guest": 8888, "host": 8888 }
  ]
}
```
- Run the following in the VM and the Jupyter Notebook will be available in your host OS's browser at `http://localhost:8888/`:
  ```bash
  jupyter notebook --no-browser --port=8888 --ip=0.0.0.0
  ```
- Additional ports can be configured in `vagrant_config.json`

### X11 Forwarding
- Enabled by default for graphical applications like GTKWave
- Windows and macOS users must run an X-server (e.g., MobaXterm, Xming) for GUI applications
- X11 forwarding is unnecessary if you set up a desktop environment through the VM GUI

### tmux Configuration
- Prefix key is set to `Ctrl-a` by default
> **Note**: May conflict with host OS keybinds and can be adjusted in tmux configuration.
- Notable hotkeys:
  - `Alt-f`: Use FZF to control tmux
  - `Alt-t`: Use tmux-sessionizer to create persistent project based sessions
  - `Alt-\`: Use floating window
  > **Note**: Commands that don't us the Prefix key may conflict with host terminal keybinds.
  - `<PREFIX>s`: Create vertical split
  - `<PREFIX>d`: Create horizontal split
- Configuration location:
  - Local: `~/.tmux.conf` within the VM
  - Persistent: `/TruVium/user-config/tmux.conf` for changes between VM rebuilds

### Vim Configuration
- Plugins can be added/removed by modifying `vagrant_setup_arch.sh` in `/TruVium/vagrant-scripts`
- `<leader>` key is mapped to `,` for custom commands
- Notable hotkeys:
  - `<C-e>`: Toggle NERDTree file explorer
  - `<leader>fv`: Autoformat VHDL code
  - `s` + two chars: EasyMotion navigation
  - `<C-p>`: Fuzzy find files
- GitHub Copilot:
  - Setup: Run `:Copilot setup` within Vim
  - Accept suggestions: `<leader>Tab` (Tab key alone may conflict with other completions)
- Configuration locations:
  - Local: `~/.vimrc` within the VM
  - Persistent: `/TruVium/user-config/vimrc` for changes between VM rebuilds
- To quit Vim `:q` or `:q!` 😉

### Vim/tmux Integration
- Seamless navigation between Vim splits and tmux panes using:
  - `<C-H>`: Move Left
  - `<C-J>`: Move Down
  - `<C-K>`: Move Up
  - `<C-L>`: Move Right
  or
  - `<S-Left Arrow>`: Move Left
  - `<S-Down Arrow>`: Move Down
  - `<S-Up Arrow>`: Move Up
  - `<S-Right Arrow>`: Move Right
- Note: Navigation may behave differently in NeoVim, Doom Emacs, or other software

### Adding Custom Tools
1. Modify the setup script:
   ```bash
   # For Arch Linux
   vagrant_setup_arch.sh
   ```
2. Add installation commands
3. Apply changes:
   ```bash
   vagrant provision
   ```

### Editor Configuration
- **Vim**: Configuration in `~/.vimrc`
- **Neovim**: Configuration in `~/.config/nvim`
- **Emacs**: Configuration in `~/.doom.d/`

## Additional Documentation

- [Desktop Environment Setup Guide](docs/desktop_environment_setup.md): Instructions for configuring desktop environments and session managers in the TruVium Vagrant VM.
> **Note**: This guide provides additional configurations for desktop environments within the TruVium Vagrant VM. Not all configurations are thoroughly tested, as TruVium's primary focus is on CLI-based HDL development.
- [Custom Keybindings](docs/custom_keybinds.md): A work-in-progress list of all configured keybindings, organized by tool for easy reference and future updates.
> **Note**: Some keybindings may require adjustment based on host terminal or OS configuration.

## Common Tasks

### Environment Management
```bash
# Update environment with new configurations
vagrant provision

# Completely rebuild environment
vagrant destroy
vagrant up

# Access the development environment
vagrant ssh
```

### Editor Commands
```bash
# Launch Vim with custom configuration
vim

# Launch Neovim with LazyVim setup
nvim

# Launch Emacs with Doom configuration
emacs
```

## Troubleshooting

### Common Issues

1. **Memory Issues**
   - Reduce `vm_memory` in `vagrant_config.json` if host system is constrained
   - Close resource-intensive applications before starting VM
   - Monitor memory usage with `htop` inside VM

2. **Port Conflicts**
   - Check for port conflicts: `netstat -tuln` on host
   - Modify port forwarding settings in `vagrant_config.json`
   - Ensure no other services are using required ports

3. **Graphics Issues**
   - Adjust `graphics_controller` in `vagrant_config.json`
   - Update VirtualBox to latest stable version
   - Verify X11 server configuration (Windows/macOS)

### Logs and Debugging
- **Detailed Vagrant Logs**:
  ```bash
  vagrant up --debug > vagrant.log 2>&1
  ```
- **Setup Logs**: Available at `/var/log/setup-script.log` inside VM
- **Real-time Log Monitoring**:
  ```bash
  tail -f /var/log/setup-script.log
  ```

## Project Structure

```
TruVium/
├── docs/                                   # Documentation directory (work in progress)
│   ├── custom_keybinds.md                  # Custom keybinding reference
│   ├── desktop_environment_setup.md        # Optional desktop environment instructions
│   └── ...                                 # Future documentation files
│
├── host-scripts/                           # Host machine setup
│   └── host_setup.sh                       # Host configuration script
│
├── proprietary/                            # Commercial tool setup (work in progress)
│   ├── config.json                         # Tool configuration
│   ├── installer.sh                        # General installation script
│   ├── installer_input_proprietary.txt
│   ├── install_modelsim.sh                 # ModelSim installation
│   └── install_vivado.sh                   # Vivado installation
│
├── templates/                              # Configuration templates
│   ├── git_setup_example.conf              # Git configuration template
│   └── host_setup_example.conf             # Host setup template
│
├── user-config/                            # User configuration files transferred into VM
│   ├── airline_theme.conf                  # Default Vim airline theme
│   ├── coc-settings.json                   # CoC configuration
│   ├── shell_configs/                      # Shell entrypoint files copied to home
│   ├── hdl_checker.json                    # HDL checker settings
│   ├── truvium/                            # Shared shell/tool configuration tree
│   ├── tmux.conf                           # tmux configuration
│   ├── tmux-sessionizer.conf               # tmux-sessionizer config
│   ├── tmuxline.conf                       # tmux statusline
│   ├── tmux_keys.sh                        # tmux-Vim integration script
│   ├── vim-themer/                         # Vim theme persistence config
│   └── vimrc                               # Vim configuration
│
├── vagrant-config/                         # Vagrant settings
│   ├── vagrant_config.json                 # VM configuration
│   └── [git_setup.conf]                    # Optional: User must add from template
│
├── vagrant-scripts/                        # VM setup scripts
│   ├── git_setup.sh                        # Git configuration script
│   └── vagrant_setup_arch.sh               # Arch Linux setup script
│
├── .gitignore                              # Git ignore patterns
├── LICENSE                                 # Project license
├── README.md                               # Project README
└── Vagrantfile                             # Vagrant main configuration
```

### Directory Descriptions

- **`docs/`**: Documentation files, including keybinding reference and guides
- **`host-scripts/`**: Scripts for setting up the host machine environment
- **`proprietary/`**: Configuration and installation scripts for commercial EDA tools
- **`templates/`**: Example configuration files for customization
- **`user-config/`**: User-specific configuration files for development tools
- **`vagrant-config/`**: VM-specific configuration files
  - Note: Users must copy, fill out, and rename `git_setup_example.conf` from templates to `git_setup.conf`
- **`vagrant-scripts/`**: Scripts for setting up and configuring the VM

### Core Files
- **`Vagrantfile`**: Main configuration file for the virtual environment
- **`README.md`**: Project documentation and setup instructions
- **`LICENSE`**: Project license information

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request with a clear description

## TODO

### Immediate Tasks
- Complete Vim plugin configuration documentation
- Add detailed keybinding reference for all editors and tmux
- Improve error handling in setup scripts
- Add more support for custom tool versions in configuration
- Add more open-source HDL tools
- Include optional proprietary tools (e.g. MATLAB, Vivado, etc.)

### Documentation
- Write detailed HDL workflow guides
- Create quickstart tutorials for new users
- Document common debugging scenarios
- Add architecture diagrams
- Improve inline code documentation

### Testing
- Implement automated testing for common workflows
- Add installation verification scripts
- Validate all tool integrations
- Test cross-platform compatibility

## Future Work

### Tool Integration
- Integrate SystemVerilog UVM support
- Add FPGA toolchain support (Xilinx, Intel)
- Implement automatic HDL project scaffolding
- Create custom HDL lint rules
- Develop integrated simulation management

### Development Environment
- Support for container-based deployment (Docker) -- Likely a future evolution
- Cloud development environment support
- Remote development capabilities
- IDE integration options (VSCode Remote)
- Improved resource management

### Features
- TruDocu HDL documentation generator
- TruDGen test data generator
- Standardized HDL file headers
- Custom HDL project templates
- Automatic dependency management

### Quality of Life
- Improved cross-platform support
- Better resource scaling
- Custom configuration profiles

## License

TruVium is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.

## Author

Kyle Orman is a member of Dr. Jia Di's TruLogic Lab and a PhD student at the University of Arkansas.

## Acknowledgments

This project leverages many outstanding open-source tools and configurations:
- Oh My Zsh: Advanced Zsh configuration framework
- tmux: Terminal multiplexer for productivity
- Vim/Neovim: Powerful text editors
- Doom Emacs: Structured editing environment
- And many other excellent tools

## Support

For bug reports and feature requests, please create an issue in the GitHub repository. Detailed bug reports and clear feature proposals are appreciated.
