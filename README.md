			████████╗██████╗ ██╗   ██╗██╗   ██╗██╗██╗   ██╗███╗   ███╗
			╚══██╔══╝██╔══██╗██║   ██║██║   ██║██║██║   ██║████╗ ████║
			   ██║   ██████╔╝██║   ██║██║   ██║██║██║   ██║██╔████╔██║
			   ██║   ██╔══██╗██║   ██║╚██╗ ██╔╝██║██║   ██║██║╚██╔╝██║
			   ██║   ██║  ██║╚██████╔╝ ╚████╔╝ ██║╚██████╔╝██║ ╚═╝ ██║
			   ╚═╝   ╚═╝  ╚═╝ ╚═════╝   ╚═══╝  ╚═╝ ╚═════╝ ╚═╝     ╚═╝

# TruVium HDL Development Environment

## Overview

TruVium is a comprehensive development environment specifically designed for hardware description language (HDL) development and general-purpose programming. It provides a fully automated setup using Vagrant, incorporating best-in-class development tools, editors, and language support.

## Features

### Core Development Environment
- **Automated Setup**: Complete environment configuration using Vagrant
- **Multi-Editor Support**: Vim, Neovim, and Emacs with extensive customization
- **Shell Environment**: Zsh with Oh My Zsh and carefully selected plugins
- **Version Control**: Advanced Git integration with custom configurations
- **Terminal Multiplexer**: tmux with optimized keybindings and status line

### HDL Development Tools
- GHDL for VHDL simulation
- GTKWave for waveform visualization
- Verilator, or iVerilog for Verilog simulation
- HDL Checker for linting
- Verible for SystemVerilog tooling

### Editor Features
#### Vim Custom Configuration
- Airline status line with theme cycling
- Git integration via Fugitive
- Code completion with CoC
- File fuzzy finding with FZF
- Syntax checking with ALE
- GitHub Copilot integration
- Custom snippet support
- Language server protocol integration

#### Neovim
- LazyVim configuration
https://www.lazyvim.org/
https://github.com/LazyVim/LazyVim


#### Emacs
- Doom Emacs configuration
https://github.com/doomemacs/doomemacs

### Language Support
- **HDL**: VHDL, Verilog, SystemVerilog
- **Scripting**: Python, Perl, Shell
- **Systems**: C, C++
- **Documentation**: LaTeX, Markdown
- **Data**: YAML, JSON
- **Web**: HTML, CSS, JavaScript

## Prerequisites

- VirtualBox 6.1 or later
- Vagrant 2.2 or later
- 6GB minimum available RAM
- 20GB minimum free disk space
- Host system supporting virtualization

## Quick Start

1. **Clone the Repository**
```bash
git clone https://github.com/yourusername/TruVium.git
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

## Configuration

### Vagrant Configuration (`vagrant_config.json`)
```json
{
  "vm_box": "archlinux/archlinux",
  "vm_memory": "6144",
  "vm_cpus": 2,
  "forward_jupyter_port": true,
  "vb_gui": false,
  "graphics_controller": "vmsvga",
  "vb_clipboard": "bidirectional"
}
```

### Port Forwarding
- 8888: Jupyter Notebook
- Additional ports configurable in `vagrant_config.json`

### X11 Forwarding
Enabled by default for graphical applications
On Windows you must run a X-server (e.g. MobaXterm, Xming)

## Installed Tools

### Development Tools
- Git with custom configurations
- tmux with enhanced status line
- Zsh + Oh My Zsh
- FZF + Ripgrep
- Language-specific linters and formatters

### Python Development
- flake8, pylint, black, mypy
- autopep8, jedi
- ipython, jupyter
- Python LSP server

### HDL Development
- GHDL
- GTKWave
- Verilator
- HDL Checker
- VSG (VHDL Style Guide)

## Customization

### Adding Custom Tools
1. Modify `vagrant_setup.sh` or `vagrant_setup_arch.sh`
2. Add installation commands
3. Run `vagrant provision`

### Editor Configuration
- Vim: `~/.vimrc`
- Neovim: `~/.config/nvim`
- Emacs: `~/.doom.d/config.el`

## Common Tasks

### Environment Management
```bash
# Update environment
vagrant provision

# Rebuild environment
vagrant destroy
vagrant up

# Access environment
vagrant ssh
```

### Editor Commands
```bash
# Start Vim with custom config
vim

# Start Neovim
nvim

# Start Emacs
emacs
```

## Troubleshooting

### Common Issues
1. **Memory Issues**
   - Reduce `vm_memory` in `vagrant_config.json`
   - Close resource-intensive applications

2. **Port Conflicts**
   - Check host port usage
   - Modify port forwarding settings

3. **Graphics Issues**
   - Adjust `graphics_controller` in configuration
   - Update VirtualBox

### Logs
- Vagrant logs: `vagrant up --debug > vagrant.log 2>&1`
- Setup logs: `/var/log/setup-script.log` inside VM

## Project Structure
```
TruVium/
├── Vagrantfile           # Vagrant configuration
├── vagrant_config.json   # Environment settings
├── vagrant_setup.sh      # Ubuntu setup script
├── vagrant_setup_arch.sh # Arch Linux setup script
├── vimrc                # Vim configuration
└── docs/                # Additional documentation
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

TruVium is licensed under the MIT License. See the [LICENSE](./LICENSE) file for details.

## Author

Kyle Orman is a member of Dr. Jia Di's TruLogic Lab and a PhD student at University of Arkansas.

## Acknowledgments

This project leverages many outstanding open-source tools and configurations:
- Oh My Zsh
- tmux
- Vim/Neovim
- Doom Emacs
- And many others

## Support

For bug reports and feature requests, please create an issue in the GitHub repository.

---

For more detailed information about specific components, please check the documentation in the `docs/` directory.