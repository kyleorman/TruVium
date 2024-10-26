			████████╗██████╗ ██╗   ██╗██╗   ██╗██╗██╗   ██╗███╗   ███╗
			╚══██╔══╝██╔══██╗██║   ██║██║   ██║██║██║   ██║████╗ ████║
			   ██║   ██████╔╝██║   ██║██║   ██║██║██║   ██║██╔████╔██║
			   ██║   ██╔══██╗██║   ██║╚██╗ ██╔╝██║██║   ██║██║╚██╔╝██║
			   ██║   ██║  ██║╚██████╔╝ ╚████╔╝ ██║╚██████╔╝██║ ╚═╝ ██║
			   ╚═╝   ╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

# HDL Development Environment

## Overview

TruVium is a comprehensive development environment specifically designed for hardware description language (HDL) development and general-purpose programming. It provides a fully automated setup using Vagrant, incorporating best-in-class development tools, editors, and language support. TruVium aims to streamline the HDL development workflow by providing a consistent, reproducible environment across different platforms.

## Features

### Core Development Environment
- **Automated Setup**: Complete environment configuration using Vagrant, an open-source tool that provides consistent development environments
- **Multi-Editor Support**: Choose between Vim, Neovim, and Emacs, each preconfigured with extensive customization for HDL development
- **Shell Environment**: Zsh shell with Oh My Zsh framework and carefully selected plugins for enhanced productivity
- **Version Control**: Advanced Git integration with custom configurations for collaborative development
- **Terminal Multiplexer**: tmux for efficient window management, session persistence, and split panes

### HDL Development Tools
- **GHDL**: An open-source VHDL simulator supporting IEEE standards, enabling compilation and simulation of VHDL designs
- **GTKWave**: A powerful waveform viewer for analyzing simulation results from VHDL and Verilog designs
- **Verilator**: High-performance Verilog/SystemVerilog simulator and lint tool for rapid design verification
- **iVerilog**: IEEE-compliant Verilog simulator for standard-compatible simulation
- **HDL Checker**: Real-time linting and syntax checking for VHDL and Verilog
- **Verible**: SystemVerilog parser, formatter, and lint tool from Google

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

- VirtualBox 6.1 or later: Virtualization platform
- Vagrant 2.2 or later: Development environment manager
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
## Usage Notes

### Operating System
- The default configuration uses Ubuntu LTS as an OS for long-term stability
- Uses the apt package manager (sudo apt-get install)
- Ubuntu LTS prioritizes stability, so many programs are installed from source to have relatively up-to-date versions, resulting in longer setup time

- You may use the alternative Arch Linux OS configuration by running:
  ```bash
  git checkout TruVium-Arch
  ```
- The package managers (pacman for official packages and yay for community packages) host more up-to-date programs
- Arch Linux setup time is significantly less by avoiding building from source and utilizing parallel installs
- The alternative configuration is more likely to break due to versioning conflicts but will be updated with new features more frequently

### Quality-of-Life Tools
TruVium prioritizes workflow efficiency through:
- tmux: Terminal multiplexer for session management
- Vi-Motions: Efficient text navigation
- FZF: Fuzzy finder for quick file and command access

## Configuration

### Host Configuration
- Apple Silicon may need a workaround since only the most recent version of VirtualBox is supported and Vagrant doesn't recognize it as an option yet
- Host terminal configuration can affect some keybindings, colors, and fonts. Using a NerdFont like FiraCode Mono for powerline symbol support is suggested. Additionally, Alacritty is a good cross-platform terminal, but a separate X-server is needed and may require configuration if you are running on Windows or macOS.

### Vagrant Configuration (`vagrant_config.json`)
- Default configuration sets vm_cpus and vm_memory to minimum values
- If your host computer can support higher settings, they can be set in `vagrant_config.json` -- this may improve setup time and user experience
- Setup time may also be improved by commenting out unnecessary installs within `vagrant_setup.sh` or `vagrant_setup_arch.sh` scripts in `/TruVium/vagrant-scripts`

```json
{
  "vm_box": "ubuntu/jammy64",
  "vm_memory": "2048",     # 2GB RAM allocation
  "vm_cpus": 1,
  "forward_jupyter_port": false,
  "vb_gui": false,
  "graphics_controller": "vmsvga",
  "vb_clipboard": "bidirectional"
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
- Prefix key is set to `Alt-1` by default
> **Note**: May conflict with host OS keybinds and can be adjusted in tmux configuration.
- After first boot in the default Ubuntu OS configuration:
  1. Run `<PREFIX> I` to install plugins
  2. Wait for the plugins to install and press enter
  3. Run `<PREFIX> U`, type all, press enter to update, and enter again after it completes
- Notable hotkeys:
  - `Alt-f`: Use FZF to control tmux
  > **Note**: May conflict with host terminal keybinds.
  - `Alt-\`: Use floating window
  - `<PREFIX>s`: Create vertical split
  - `<PREFIX>d`: Create horizontal split
- Configuration location:
  - Local: `~/.tmux.conf` within the VM
  - Persistent: `/TruVium/user-config/tmux.conf` for changes between VM rebuilds

### Vim Configuration
- Plugins can be added/removed by modifying the `vagrant_setup.sh` or `vagrant_setup_arch.sh` scripts in `/TruVium/vagrant-scripts`
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
- Note: Navigation may behave differently in NeoVim, Doom Emacs, or other software

### Adding Custom Tools
1. Modify appropriate setup script:
   ```bash
   # For Ubuntu
   vagrant_setup.sh
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
- **Emacs**: Configuration in `~/.doom.d/config.el`

## Additional Documentation

- [Desktop Environment Setup Guide](docs/desktop_environment_setup.md): Instructions for configuring desktop environments and session managers in the TruVium Vagrant VM.
> **Note**: This guide provides additional configurations for desktop environments within the TruVium Vagrant VM. Not all configurations are thoroughly tested, as TruVium’s primary focus is on CLI-based HDL development.
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
├── user-config/                            # User configuration files transfered into VM
│   ├── airline_theme.conf                  # Default Vim airline theme
│   ├── coc-settings.json                   # CoC configuration
│   ├── color_scheme.conf                   # Default Vim color settings
│   ├── hdl_checker.json                    # HDL checker settings
│   ├── tmux.conf                           # tmux configuration
│   ├── tmuxline.conf                       # tmux statusline
│   ├── tmux_keys.sh                        # tmux-Vim integration script
│   └── vimrc                               # Vim configuration
│
├── vagrant-config/                         # Vagrant settings
│   ├── vagrant_config.json                 # VM configuration
│   └── [git_setup.conf]                    # Optional: User must add from template
│
├── vagrant-scripts/                        # VM setup scripts
│   ├── git_setup.sh                        # Git configuration script
│   ├── vagrant_setup.sh                    # Ubuntu setup script
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

---

For more detailed information about specific components, please check the documentation in the `docs/` directory.