# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Platform update tool for Distiller systems that automatically applies system-level configuration updates to bring older Distiller images up to parity with the latest pi-gen builds. This package is designed to be installed once via APT and performs idempotent platform updates during installation/upgrade.

**Package Name**: distiller-platform-update
**Version**: 2.0.0
**Architecture**: all (architecture-independent)
**Type**: Debian package with postinst automation

## Purpose

This tool transforms older Distiller system images by:
- Configuring APT repositories (debian.griffo.io, apt.pamir.ai)
- Installing udev rules for hardware (SD card, Pico)
- Patching boot partition configuration (config.txt, cmdline.txt)
- Setting up SD card automount (PolicyKit + udisks2)
- Configuring environment variables and user permissions
- Setting up log rotation for Distiller services

The tool tracks platform version in `/etc/distiller-platform-info` and only applies updates when upgrading from versions < 2.0.0.

## Build System

### Building the Package

```bash
# Build Debian package
just build

# The package will be created in dist/
# Output: dist/distiller-platform-update_2.0.0_all.deb
```

### Available Just Recipes

```bash
just --list              # Show all recipes
just build              # Build Debian package (uses debuild)
just clean              # Clean build artifacts
just changelog          # Update debian/changelog (uses dch -i)
```

### Build Process

The build system uses `debuild` with these options:
- `-us -uc`: No signing
- `-b`: Binary-only build
- `-d`: Skip dependency checks
- `--lintian-opts --profile=debian`: Run lintian checks

Built packages are moved to `dist/` and temporary build artifacts are cleaned up.

## Architecture

### Key Components

**1. Platform Detection** (`lib/platform-detect.sh`)
- Detects hardware platform by reading `/proc/cpuinfo` and `/proc/device-tree/model`
- Supports: cm5 (Raspberry Pi CM5), radxa-zero3, armsom-cm5
- Returns "unknown" for unsupported platforms

**2. Boot Configuration Patcher** (`lib/boot-patcher.sh`)
- Patches `/boot/firmware/config.txt` and `/boot/firmware/cmdline.txt`
- Uses marker comments to track Distiller configuration blocks
- Performs smart merge: preserves user customizations while updating defaults
- Handles duplicate directives by commenting them out with explanations
- Backs up original files to `/var/backups/distiller-platform-update/boot/`

**Key boot-patcher features:**
- Idempotent: Can be run multiple times safely
- Preserves section headers ([eeprom], etc.)
- Special handling for dtoverlay/dtparam (can have multiple instances)
- Comments out duplicates found outside Distiller block

**3. Post-Installation Script** (`debian/postinst`)
- Main orchestrator that runs during package installation
- Checks platform version in `/etc/distiller-platform-info`
- Only applies updates if upgrading from version < 2.0.0
- Four-phase update process:
  1. APT repository configuration
  2. Environment variables and user groups
  3. Hardware rules and automount
  4. Boot partition patching

**4. Configuration Data** (`usr/share/distiller-platform-update/data/`)
- `apt/sources.list.d/`: Repository configuration files
- `apt/keyrings/`: GPG keys for repositories
- `boot/`: Boot configuration additions (config.txt, cmdline.txt)
- `environment/`: Environment variables for SDK integration
- `udev/`: Hardware detection rules
- `polkit-1/`: PolicyKit rules for automount
- `logrotate.d/`: Log rotation configuration

### Platform Info File

The tool creates and maintains `/etc/distiller-platform-info`:

```
DISTILLER_PLATFORM_VERSION=2.0.0
DISTILLER_INSTALL_DATE=2025-10-29T15:30:00+0530
DISTILLER_INSTALL_METHOD=apt
DISTILLER_PLATFORM=cm5
REPOS_CONFIGURED=yes
ENVIRONMENT_CONFIGURED=yes
AUTOMOUNT_CONFIGURED=yes
HARDWARE_CONFIGURED=yes
BOOT_CONFIGURED=yes
```

Feature flags track which updates have been applied.

### Boot Configuration Strategy

**cmdline.txt patching:**
- Appends kernel parameters: `earlyprintk loglevel=8`
- Maintains single-line format (required by Raspberry Pi bootloader)
- Checks for existing parameters before adding

**config.txt patching:**
- Intelligent block-based merging
- Preserves user customizations within Distiller block
- Comments out duplicate directives found elsewhere
- Handles sections like [eeprom] correctly
- Supports dtoverlay/dtparam with different values

The boot patcher uses marker comments:
```
# Distiller CM5 Hardware Configuration
... config directives ...
# End Distiller CM5 Hardware Configuration
```

### Installation Paths

- Package data: `/usr/share/distiller-platform-update/`
- Libraries: `/usr/share/distiller-platform-update/lib/`
- Configuration templates: `/usr/share/distiller-platform-update/data/`
- Runtime state: `/var/lib/distiller-platform-update/`
- Logs: `/var/log/distiller-platform-update/`
- Backups: `/var/backups/distiller-platform-update/`

## Debian Packaging

### Package Structure

```
debian/
├── control              # Package metadata, dependencies
├── changelog            # Version history (managed by dch)
├── postinst            # Main update orchestration
├── preinst             # Pre-installation checks
├── prerm               # Pre-removal cleanup
├── postrm              # Post-removal cleanup
├── rules               # debhelper build rules
├── source/format       # Source package format
└── distiller-platform-update.install  # File installation map
```

### Version Management

```bash
# Update package version
dch -v 2.1.0            # Set specific version
dch -i                  # Increment version
dch -a "Description"    # Add changelog entry

# After updating changelog, rebuild
just build
```

### Dependencies

Required packages (automatically installed):
- apt (repository management)
- systemd (service management)
- udev (hardware rules)
- polkitd or policykit-1 (automount authorization)

Recommended packages (optional but suggested):
- distiller-genesis-common
- distiller-genesis-cm5
- distiller-genesis-rockchip

## Testing & Debugging

### Manual Installation

```bash
# Build and install locally
just build
sudo dpkg -i dist/distiller-platform-update_2.0.0_all.deb

# Check platform info after installation
cat /etc/distiller-platform-info

# Verify APT repositories
ls -la /etc/apt/sources.list.d/ | grep -E "debian.griffo|pamir-ai"
cat /etc/apt/sources.list.d/pamir-ai.list

# Check boot configuration
cat /boot/firmware/config.txt | grep -A 30 "Distiller CM5"
cat /boot/firmware/cmdline.txt
```

### Testing Boot Patcher

```bash
# Run boot patcher manually (requires root)
sudo /usr/share/distiller-platform-update/lib/boot-patcher.sh

# Check backups
ls -la /var/backups/distiller-platform-update/boot/

# Verify no duplicates in config.txt
grep -n "dtoverlay=spi0-1cs" /boot/firmware/config.txt
```

### Platform Detection

```bash
# Test platform detection
/usr/share/distiller-platform-update/lib/platform-detect.sh

# Manual platform check
cat /proc/cpuinfo | grep "Raspberry Pi Compute Module 5"
cat /proc/device-tree/model
```

### Simulating Upgrades

To test the upgrade path from old versions:

```bash
# Create fake old platform info
sudo bash -c 'cat > /etc/distiller-platform-info <<EOF
DISTILLER_PLATFORM_VERSION=1.0.0
DISTILLER_INSTALL_DATE=$(date -Iseconds)
DISTILLER_INSTALL_METHOD=apt
DISTILLER_PLATFORM=cm5
EOF'

# Reinstall package to trigger upgrade logic
sudo dpkg -i dist/distiller-platform-update_2.0.0_all.deb

# Verify all updates applied
cat /etc/distiller-platform-info | grep "=yes"
```

## Important Implementation Notes

### Idempotency

All update operations are idempotent and safe to run multiple times:
- Platform version checks prevent redundant updates
- Boot patcher checks for existing configuration before adding
- File operations verify existence before modification
- Feature flags track completed updates

### Error Handling

The postinst script uses defensive error handling:
- Platform detection failures default to "unknown" instead of exiting
- File copy failures print warnings but continue execution
- Boot patcher failures are logged but don't abort installation
- Invalid VERSION file format falls back to "2.0.0"

### Boot Configuration Risks

**IMPORTANT**: Boot configuration changes can prevent system from booting. The boot patcher:
- Always creates timestamped backups before modification
- Validates file existence before patching
- Uses safe sed operations with in-place editing
- Preserves exact formatting of cmdline.txt (single line)

If boot fails after update:
1. Boot into recovery mode
2. Restore from backup: `/var/backups/distiller-platform-update/boot/`
3. Check dmesg/kernel logs for boot errors

### User Groups

The postinst adds the `distiller` user to required groups:
- netdev: Network management
- input: Input device access
- i2c, spi, gpio: Hardware interfaces
- dialout: Serial port access
- audio, video: Media hardware

## Common Development Workflows

### Making Changes to Boot Configuration

```bash
# 1. Edit the configuration template
vim usr/share/distiller-platform-update/data/boot/config.additions

# 2. Rebuild package
just build

# 3. Test on a VM or test device (NEVER production)
sudo dpkg -i dist/distiller-platform-update_2.0.0_all.deb

# 4. Verify boot configuration was updated correctly
cat /boot/firmware/config.txt

# 5. Test reboot
sudo reboot

# 6. If boot fails, restore from backup
sudo cp /var/backups/distiller-platform-update/boot/config.txt.YYYYMMDD_HHMMSS /boot/firmware/config.txt
```

### Adding New Platform Support

```bash
# 1. Update platform-detect.sh
vim usr/share/distiller-platform-update/lib/platform-detect.sh

# Add new detection logic:
# elif grep -q "New Board" /proc/device-tree/model 2>/dev/null; then
#     echo "new-board"

# 2. Update postinst if platform needs special handling
vim debian/postinst

# 3. Test detection
./usr/share/distiller-platform-update/lib/platform-detect.sh

# 4. Rebuild and test
just build
```

### Updating Package Version

```bash
# 1. Update VERSION file
echo "2.1.0" > VERSION

# 2. Update changelog
dch -v 2.1.0 "Description of changes"

# 3. Rebuild
just clean
just build

# 4. Verify version in built package
dpkg-deb -I dist/distiller-platform-update_2.1.0_all.deb | grep Version
```

## Integration with Distiller Ecosystem

This package is part of the larger Distiller platform:
- **distiller-sdk**: Core hardware SDK (requires PYTHONPATH, LD_LIBRARY_PATH)
- **distiller-genesis-***: Platform-specific base images
- **distiller-services**: System services (WiFi, telemetry, etc.)

The platform-update tool ensures all images, regardless of when they were built, have consistent system configuration for running Distiller packages.

Environment variables configured by this tool:
- `DISTILLER_PLATFORM`: Detected hardware platform (cm5, radxa-zero3, armsom-cm5)
- `PYTHONPATH`: Includes `/opt/distiller-sdk/src`
- `LD_LIBRARY_PATH`: Includes `/opt/distiller-sdk/lib`

These variables are written to `/etc/environment` for system-wide availability.
