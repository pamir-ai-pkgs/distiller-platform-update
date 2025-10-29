# distiller-platform-update

Platform update tool for Distiller systems that automatically brings older system images up to parity with the latest pi-gen builds.

## Overview

This package automatically applies system-level configuration updates during installation, ensuring all Distiller devices have consistent platform configuration regardless of when the base image was created.

## What It Updates

- **APT Repositories**: Configures debian.griffo.io and apt.pamir.ai repositories with GPG keys
- **Boot Configuration**: Optimizes CPU frequency, fan control, SPI, UART, and camera settings
- **Hardware Support**: Installs udev rules for SD card automount and Pico devices
- **Environment**: Configures SDK paths and adds distiller user to required groups (audio, video, spi, gpio, etc.)
- **System Services**: Enables udisks2 for SD card automount with PolicyKit rules

## Installation

```bash
sudo apt install distiller-platform-update
```

The package performs all updates automatically during installation. No manual configuration required.

## Supported Platforms

- Raspberry Pi Compute Module 5 (CM5)
- Radxa Zero 3 / 3W
- ArmSom CM5 IO

Platform is detected automatically via `/proc/cpuinfo` and `/proc/device-tree/model`.

## How It Works

The package tracks platform version in `/etc/distiller-platform-info` and only applies updates when upgrading from versions < 2.0.0. All operations are idempotent and safe to run multiple times.

### Update Process

1. Detect hardware platform
2. Configure APT repositories and keyrings
3. Set environment variables (DISTILLER_PLATFORM, PYTHONPATH, LD_LIBRARY_PATH)
4. Install udev rules and PolicyKit automount configuration
5. Patch `/boot/firmware/config.txt` and `/boot/firmware/cmdline.txt`
6. Update platform version to 2.0.0

### Boot Configuration

Boot files are patched intelligently:
- Creates timestamped backups in `/var/backups/distiller-platform-update/boot/`
- Preserves user customizations within the Distiller configuration block
- Comments out duplicate directives found outside the Distiller block
- Safe to reinstall - will not overwrite user changes

If boot issues occur after update, restore from backup:
```bash
sudo cp /var/backups/distiller-platform-update/boot/config.txt.* /boot/firmware/config.txt
sudo reboot
```

## Verification

Check platform info after installation:
```bash
cat /etc/distiller-platform-info
```

Expected output:
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

Verify boot configuration:
```bash
grep -A 30 "Distiller CM5" /boot/firmware/config.txt
```

## Building from Source

```bash
# Build Debian package
just build

# Install locally
sudo dpkg -i dist/distiller-platform-update_2.0.0_all.deb
```

## Integration

This package is part of the Distiller platform ecosystem:
- **distiller-sdk**: Core hardware SDK
- **distiller-genesis-***: Platform-specific base images
- **distiller-services**: System services (WiFi provisioning, telemetry)

Environment variables configured by this package ensure proper SDK integration for all Distiller software.

## Troubleshooting

### Platform detection fails
```bash
# Manually check platform
/usr/share/distiller-platform-update/lib/platform-detect.sh
cat /proc/device-tree/model
```

### Boot configuration issues
All original boot files are backed up before modification:
```bash
ls -la /var/backups/distiller-platform-update/boot/
```

### Verify APT repositories
```bash
cat /etc/apt/sources.list.d/pamir-ai.list
cat /etc/apt/sources.list.d/debian.griffo.io.list
```

### Check installation logs
```bash
journalctl -u dpkg -g "distiller-platform-update"
```

## License

Copyright (c) 2025 PamirAI Incorporated

## Support

- Issues: https://github.com/pamir-ai-pkgs/distiller-platform-update/issues
- Contact: founders@pamir.ai
