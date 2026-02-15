# Vagrant Setup and Desktop Environment Configuration Guide (Arch Linux)

This guide provides step-by-step instructions for setting up a Vagrant VM with a desktop environment on Arch Linux using a session manager. It also covers necessary configurations and steps to enable the VirtualBox GUI and access the desktop session.

> **⚠️ Warning**  
> Not all configuration options in this guide have been thoroughly tested, as the primary goal of TruVium is HDL development in the CLI. GUI configurations, including desktop environments and session managers, are offered for convenience but may require additional adjustments.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Initial Setup Steps](#initial-setup-steps)
3. [Configuring Desktop Environment and Session Manager](#configuring-desktop-environment-and-session-manager)
4. [Updating `vagrant_config.json` for GUI Access](#updating-vagrant_configjson-for-gui-access)
5. [Accessing the Desktop Environment](#accessing-the-desktop-environment)
6. [Adjusting Display Settings](#adjusting-display-settings)
7. [Full `vagrant_config.json` Example](#full-vagrant_configjson-example)

---

## Prerequisites

Ensure you have the following tools installed and accessible from your host machine:

- **Vagrant**
- **VirtualBox**
- **MobaXterm** or another SSH client that supports X11 forwarding (if needed)
- Basic familiarity with editing JSON configuration files

---

## Initial Setup Steps

1. **SSH into the VM**:
   Use the following command to SSH into your Vagrant VM:
   ```bash
   vagrant ssh
   ```

2. **Install a Desktop Environment with Session Manager**:
   Select a desktop environment that includes a session manager. Here are options for **Arch Linux**:

#### Arch Linux TruVium Configuration

1. **GNOME** (includes GDM):
   ```bash
   sudo pacman -S gnome gnome-extra
   sudo systemctl enable gdm.service --now
   ```

2. **KDE Plasma** (includes SDDM):
   ```bash
   sudo pacman -S plasma kde-applications
   sudo systemctl enable sddm.service --now
   ```

3. **MATE** (requires LightDM):
   ```bash
   sudo pacman -S mate mate-extra lightdm lightdm-gtk-greeter
   sudo systemctl enable lightdm.service --now
   ```

4. **Xfce** (requires installing LightDM):
   ```bash
   sudo pacman -S xfce4 xfce4-goodies lightdm lightdm-gtk-greeter
   sudo systemctl enable lightdm.service --now
   ```

5. **LXQt** (includes SDDM):
   ```bash
   sudo pacman -S lxqt sddm
   sudo systemctl enable sddm.service --now
   ```

---

## Configuring Desktop Environment and Session Manager

Ensure the session manager is enabled for the selected environment if it’s not already.

> **Note**: The examples below activate the session manager only if it’s not set up automatically.

- **GDM for GNOME**:
  ```bash
  sudo systemctl enable gdm.service --now
  ```

- **SDDM for KDE Plasma**:
  ```bash
  sudo systemctl enable sddm.service --now
  ```

- **LightDM for MATE**:
  ```bash
  sudo systemctl enable lightdm.service --now
  ```

> **Tip**: If the session manager fails to start, check logs with `journalctl -xe`.

---

## Updating `vagrant_config.json` for GUI Access

To access the desktop environment via the VirtualBox GUI, update `vagrant_config.json` to enable GUI mode.

1. Open `/TruVium/vagrant-config/vagrant_config.json` for editing.
2. Locate the `"vb_gui"` key and change its value to `true`.

---

## Accessing the Desktop Environment

After enabling GUI mode in `vagrant_config.json`:

1. **Reload the Vagrant VM**:
   ```bash
   vagrant reload
   ```
   This command restarts the VM with the new settings.

2. **Access the VirtualBox GUI**:
   The VirtualBox GUI should open to the session manager.

3. **Select and Log In to the Desktop Environment**:
   - Select the installed desktop environment.
   - Use the following credentials to log in:
     - **Username**: `vagrant`
     - **Password**: `vagrant`

---

## Adjusting Display Settings

Once logged into the desktop environment, you can adjust display settings as needed.

1. **Access Display Settings**: 
   - Navigate to **Settings > Display** or a similar menu based on the desktop environment.
2. **Configure Multi-Monitor Setup**: 
   - Adjust resolutions, orientations, and monitor positioning as per your setup.

> **Note**: Ensure that multi-monitor settings are compatible with the VM configuration in VirtualBox.

---

### Advanced Configuration

If you do not mind possible additional configuration you can install a session manager and desktop environment separately.

> **Note**: Cinnamon is highly recommended if you are used to Windows type systems.

#### Step 1: Install a Standalone Session Manager

##### Arch Linux TruVium Configuration
1. **GDM**:
   ```bash
   sudo pacman -S gdm
   sudo systemctl enable gdm.service --now
   ```

2. **LightDM**:
   ```bash
   sudo pacman -S lightdm lightdm-gtk-greeter
   sudo systemctl enable lightdm.service --now
   ```

3. **SDDM**:
   ```bash
   sudo pacman -S sddm
   sudo systemctl enable sddm.service --now
   ```

#### Step 2: Install a Standalone Desktop Environment

Once a session manager is installed and enabled, add a standalone desktop environment.

##### Arch Linux TruVium Configuration

1. **Cinnamon**:
   ```bash
   sudo pacman -S cinnamon
   ```

2. **LXDE**:
   ```bash
   sudo pacman -S lxde
   ```

3. **i3 (tiling window manager)**:
   ```bash
   sudo pacman -S i3
   ```

4. **Openbox**:
   ```bash
   sudo pacman -S openbox
   ```

5. **Fluxbox**:
   ```bash
   sudo pacman -S fluxbox
   ```

> **Note**: After installing a standalone desktop environment, follow the same steps under **Updating `vagrant_config.json` for GUI Access** and continue to **Accessing the Desktop Environment** to launch your configured GUI.
