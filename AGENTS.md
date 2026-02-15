# AGENTS.md

## Project Overview

TruVium is a Vagrant-managed development environment for HDL and general software work.

- Primary target is an Arch Linux VM managed through VirtualBox + Vagrant.
- Main provisioning entrypoint is `vagrant-scripts/vagrant_setup_arch.sh`.
- Configuration flows from `vagrant-config/vagrant_config.json` into `Vagrantfile`.
- Persistent user tooling configuration lives in `user-config/` and is applied inside the VM.
- This repo is infrastructure/configuration heavy (shell scripts, Vagrant Ruby, JSON, docs), not an application service.

## Repository Map

- `Vagrantfile`: Core VM orchestration and config parsing.
- `vagrant-config/`: User-editable VM settings (`vagrant_config.json`).
- `vagrant-scripts/`: Provisioning scripts (`vagrant_setup_arch.sh`, `git_setup.sh`, legacy `vagrant_setup.sh`).
- `user-config/`: Persistent dotfiles and editor/shell/tmux/tool configs copied into VM.
- `host-scripts/`: Optional host-side setup script(s).
- `proprietary/`: Optional proprietary tool installers (work in progress).
- `templates/`: Example config files users copy and customize.
- `docs/`: Supplemental guides.

## Build and Test Commands

Use these host-side commands during development.

### Environment lifecycle

- `vagrant up`: Create and boot VM.
- `vagrant provision`: Re-run provisioning against existing VM.
- `vagrant ssh`: Enter VM.
- `vagrant reload`: Restart VM and reload configuration.
- `vagrant halt`: Stop VM.
- `vagrant destroy`: Delete VM.

### Fast validation (preferred before full provision)

- `ruby -c Vagrantfile`
- `bash -n host-scripts/host_setup.sh`
- `bash -n vagrant-scripts/git_setup.sh`
- `bash -n vagrant-scripts/vagrant_setup_arch.sh`
- `bash -n vagrant-scripts/vagrant_setup.sh`
- `bash -n proprietary/installer.sh`
- `bash -n proprietary/install_vivado.sh`
- `bash -n proprietary/install_modelsim.sh`

If `shellcheck` is installed, run it on edited shell scripts as an additional check.

### Full validation (slow)

- Run `vagrant provision` for most script/config changes.
- For first-time setup changes, run `vagrant up` from a clean VM.
- Inside the VM, confirm key tools relevant to your change (for example `ghdl --version`, `verilator --version`, `yosys -V`, `tmux -V`).

## Code Style Guidelines

### Shell scripts

- Use Bash and keep strict mode (`set -eEuo pipefail`) where already used.
- Quote variables and paths unless deliberate word splitting is required.
- Prefer small helper functions and explicit error messages.
- Keep scripts idempotent; provisioning is expected to be re-runnable.
- Guard distro-specific logic (Arch vs Ubuntu) explicitly.

### Vagrantfile (Ruby)

- Keep behavior config-driven via `vagrant-config/vagrant_config.json`.
- Use safe defaults (`settings.fetch(...)` or `||`) for new keys.
- Preserve existing host/guest path assumptions (`/vagrant` shared repo path).

### JSON and config files

- Use 2-space indentation.
- Avoid trailing commas.
- Add new keys with backward-compatible defaults in `Vagrantfile`.

### Documentation

- Update `README.md` and/or `docs/` when user-visible setup behavior changes.
- Keep examples runnable and consistent with current defaults (Arch-first).

## Testing Instructions

There is no CI workflow in this repository at the time of writing.

- Minimum for non-trivial changes: run syntax checks for all touched scripts/files.
- For provisioning changes: run `vagrant provision` and inspect output for regressions.
- For VM bootstrap changes: validate with a clean VM (`vagrant destroy` then `vagrant up`) when practical.
- Check setup logs inside VM at `/var/log/setup-script.log`.
- For deep Vagrant troubleshooting, run `vagrant up --debug > vagrant.log 2>&1`.

## Security Considerations

- Do not commit secrets, credentials, tokens, private keys, or machine-specific identifiers.
- Treat user-created config files such as `vagrant-config/git_setup.conf` as sensitive.
- Be careful in `proprietary/`: installers may depend on licensed assets and local paths.
- Do not add large binary artifacts unless explicitly requested.

## Common Agent Workflows

### Add a new VM tool/package

1. Update install logic in `vagrant-scripts/vagrant_setup_arch.sh` (and Ubuntu script only if still intended).
2. Add default config/assets in `user-config/` if needed.
3. Validate with syntax checks, then `vagrant provision`.
4. Document user-facing behavior changes.

### Add a new Vagrant setting

1. Add setting in `vagrant-config/vagrant_config.json`.
2. Parse and default it in `Vagrantfile`.
3. Keep behavior backward compatible.
4. Update docs.

### Update editor/shell defaults

1. Modify relevant files under `user-config/`.
2. Ensure provisioning copies/applies updates.
3. Validate inside VM.

## Extra Instructions for Agents

- Prefer minimal, focused diffs over large refactors.
- Follow existing style in each file before introducing new patterns.
- If README and implementation disagree, treat implementation as source of truth and update docs.
- Ignore unrelated local changes in the working tree.
- Delete `plan.md` after plan-guided implementation is complete.
- Delete `review.md` after review findings have been fully addressed.
- In final handoff, report what was changed, what was validated, and any remaining risks.
