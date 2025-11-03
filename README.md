# distiller-platform-update

System configuration updater for Distiller devices - automatically brings older system images up to parity with latest builds.

## Overview

`distiller-platform-update` is a Debian package that automatically applies platform-level configuration updates when installed or upgraded. It ensures that older Distiller device images (Raspberry Pi CM5, Radxa Zero 3/3W, ArmSom CM5 IO) are configured with the latest APT repositories, boot settings, hardware rules, and environment variables.

**Key characteristics**:
- Runs automatically during package installation/upgrade (via `postinst`)
- Idempotent and safe to re-run multiple times
- Creates timestamped backups before modifying system files
- Tracks platform version in `/etc/distiller-platform-info`
- Architecture-independent (works on all ARM64 platforms)

## Features

- **APT Repository Configuration**: Adds Distiller APT sources and GPG keys
- **Boot Partition Optimization**: Applies hardware-specific boot configuration (requires reboot)
- **Environment Variables**: Sets `DISTILLER_PLATFORM`, `PYTHONPATH`, `LD_LIBRARY_PATH`
- **Hardware Permissions**: Adds distiller user to audio, video, spi, gpio, i2c groups
- **Udev Rules**: Configures SD card automount and Pico device rules
- **Sudoers Configuration**: Grants passwordless sudo for hardware access
- **PolicyKit Rules**: Enables automatic disk mounting via udisks2
- **Log Rotation**: Configures log rotation for platform update logs
- **NVM + Node.js**: Installs NVM and Node.js v20.19.5 for distiller user
- **Claude Code CLI**: Installs Claude Code development environment (optional)

## Installation

### From Debian Package (Recommended)

```bash
# Download latest release
wget https://github.com/pamir-ai-pkgs/distiller-platform-update/releases/latest/download/distiller-platform-update_2.0.0_all.deb

# Install (requires root)
sudo dpkg -i distiller-platform-update_2.0.0_all.deb

# Reboot to apply boot configuration changes
sudo reboot
```

### From Source

```bash
# Prerequisites
sudo apt-get install build-essential debhelper just

# Clone and build
git clone https://github.com/pamir-ai-pkgs/distiller-platform-update.git
cd distiller-platform-update
just build

# Install
sudo dpkg -i dist/distiller-platform-update_2.0.0_all.deb
sudo reboot
```

## Usage

### Automatic Updates

The package runs automatically during installation/upgrade. No user interaction is required.

```bash
# Install triggers automatic update
sudo dpkg -i distiller-platform-update_*.deb

# Upgrade triggers incremental update
sudo apt-get update && sudo apt-get upgrade distiller-platform-update
```

### Manual Update

If needed, you can manually trigger the update orchestrator:

```bash
sudo /usr/share/distiller-platform-update/lib/update-orchestrator.sh
```

### Check Platform Version

```bash
# View current platform version and configuration
cat /etc/distiller-platform-info
```

Example output:
```
DISTILLER_PLATFORM_VERSION=2.0.0
DISTILLER_PLATFORM=cm5
DISTILLER_INSTALLATION_DATE=2025-10-29_15:30:00
DISTILLER_INSTALLATION_METHOD=debian_package
APT_REPOS_CONFIGURED=yes
ENV_VARS_CONFIGURED=yes
USER_GROUPS_CONFIGURED=yes
UDEV_RULES_CONFIGURED=yes
SUDOERS_CONFIGURED=yes
AUTOMOUNT_CONFIGURED=yes
LOGROTATE_CONFIGURED=yes
BOOT_PATCHER_CONFIGURED=yes
NVM_INSTALLED=yes
CLAUDE_CODE_INSTALLED=yes
```

## What Gets Updated

The update process runs these phases in order:

| Phase | Script | Description |
|-------|--------|-------------|
| 1 | `apt-repos.sh` | Configures Distiller APT repositories and GPG keys |
| 2 | `env-vars.sh` | Sets platform environment variables in `/etc/environment` |
| 3 | `user-groups.sh` | Adds distiller user to hardware access groups |
| 4 | `udev-rules.sh` | Installs udev rules for SD cards and Pico devices |
| 5 | `sudoers-setup.sh` | Configures passwordless sudo for hardware operations |
| 6 | `automount-setup.sh` | Sets up PolicyKit rules for automatic disk mounting |
| 7 | `logrotate-setup.sh` | Configures log rotation for platform update logs |
| 8 | `boot-patcher.sh` | Patches `/boot/firmware/config.txt` (requires reboot) |
| 9 | `nvm-install.sh` | Installs NVM and Node.js v20.19.5 for distiller user |
| 10 | `claude-code-installer.sh` | Installs Claude Code CLI for development |

### Update Behavior

- **First Installation** (version < 2.0.0): Runs all update phases
- **Incremental Update** (version >= 2.0.0): Only updates missing components
- **Non-Fatal Helpers**: Developer tools (NVM, Claude Code) use best-effort installation (won't fail package install)

## Configuration

### Platform Detection

The package automatically detects your platform by reading `/proc/cpuinfo` and `/proc/device-tree/model`:

- `cm5` - Raspberry Pi CM5
- `radxa-zero3` - Radxa Zero 3/3W
- `armsom-cm5` - ArmSom CM5 IO
- `unknown` - Unsupported platform (limited functionality)

Check detected platform:
```bash
/usr/share/distiller-platform-update/lib/platform-detect.sh
```

### Environment Variables

After installation, these variables are set in `/etc/environment`:

| Variable | Value | Description |
|----------|-------|-------------|
| `DISTILLER_PLATFORM` | `cm5`, `radxa-zero3`, `armsom-cm5` | Detected hardware platform |
| `PYTHONPATH` | `/opt/distiller-sdk:...` | Python SDK path |
| `LD_LIBRARY_PATH` | `/opt/distiller-sdk/lib:...` | Shared library path |

Reload environment after installation:
```bash
source /etc/environment
```

### Boot Configuration

The boot patcher modifies `/boot/firmware/config.txt` with hardware-specific settings. All changes are placed within marker blocks:

```
# Distiller CM5 Hardware Configuration
# (Automatically managed by distiller-platform-update)
...
# End Distiller CM5 Hardware Configuration
```

**Important**: A reboot is required after installation for boot changes to take effect.

## Troubleshooting

### Boot Configuration Not Applied

**Symptom**: After installation, hardware features don't work (e-ink, audio, etc.)

**Solution**:
```bash
# Check if boot patcher ran successfully
grep "BOOT_PATCHER_CONFIGURED=yes" /etc/distiller-platform-info

# Check boot configuration
sudo cat /boot/firmware/config.txt | grep -A 20 "Distiller CM5 Hardware Configuration"

# Reboot if changes not applied
sudo reboot
```

### Permission Denied Errors

**Symptom**: Hardware access fails with permission errors

**Solution**:
```bash
# Check group membership
groups

# Should include: audio, video, spi, gpio, i2c
# If not, log out and back in, or reboot

# Verify udev rules installed
ls -la /etc/udev/rules.d/ | grep distiller
```

### Platform Detection Incorrect

**Symptom**: Wrong platform detected or shows "unknown"

**Solution**:
```bash
# Check platform detection
/usr/share/distiller-platform-update/lib/platform-detect.sh

# View device tree model
cat /proc/device-tree/model

# View CPU info
cat /proc/cpuinfo | grep -i model
```

### Update Fails During Installation

**Symptom**: Package installation fails with update orchestrator errors

**Solution**:
```bash
# View installation logs
journalctl -u dpkg -g "distiller-platform-update"

# View platform update logs
sudo tail -f /var/log/distiller-platform-update/platform-update.log

# Check disk space (backups require space)
df -h /var/backups

# Manually re-run update
sudo /usr/share/distiller-platform-update/lib/update-orchestrator.sh
```

### Boot Configuration Restore

**Symptom**: Need to restore previous boot configuration

**Solution**:
```bash
# List available backups
ls -la /var/backups/distiller-platform-update/boot/

# Restore specific backup (replace timestamp)
sudo cp /var/backups/distiller-platform-update/boot/config.txt.20251029_153000 /boot/firmware/config.txt
sudo reboot
```

## File Locations

| Path | Description |
|------|-------------|
| `/usr/share/distiller-platform-update/` | Installation directory |
| `/etc/distiller-platform-info` | Platform version and configuration status |
| `/etc/environment` | Environment variables |
| `/etc/sudoers.d/distiller-hardware` | Sudoers configuration |
| `/etc/udev/rules.d/` | Udev rules |
| `/etc/polkit-1/rules.d/` | PolicyKit rules |
| `/etc/logrotate.d/distiller-platform-update` | Log rotation configuration |
| `/boot/firmware/config.txt` | Boot configuration (modified) |
| `/var/backups/distiller-platform-update/` | Timestamped backups |
| `/var/log/distiller-platform-update/` | Platform update logs |

## Development

### Building the Package

```bash
# Install dependencies
sudo apt-get install build-essential debhelper just

# Build Debian package
just build

# Output: dist/distiller-platform-update_2.0.0_all.deb
```

### Testing Boot Patcher

```bash
# Test boot patcher (creates backup)
sudo ./usr/share/distiller-platform-update/scripts/boot-patcher.sh

# Compare changes
diff /var/backups/distiller-platform-update/boot/config.txt.* /boot/firmware/config.txt
```

### Adding New Update Phases

1. Create script in `usr/share/distiller-platform-update/scripts/`
2. Source `../lib/shared.sh` at top of script
3. Make idempotent (safe to run multiple times)
4. Add to `lib/update-orchestrator.sh` in correct order
5. Add configuration flag to `/etc/distiller-platform-info`

## License

MIT License - See LICENSE file for details.

## Support

- **Issues**: https://github.com/pamir-ai-pkgs/distiller-platform-update/issues
