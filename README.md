# distiller-migrator

Migration tool for transitioning Distiller platform packages from pamir-ai to pamir-ai-pkgs organization.

## Overview

This package provides the migration framework for transitioning the Distiller CM5 platform from the legacy `pamir-ai` package organization to the new `pamir-ai-pkgs` organization. It handles repository configuration updates, package deprecation, replacement, and rollback capabilities.

## Features

- **Repository Migration**: Updates APT sources from pamir-ai to pamir-ai-pkgs
- **Package Replacement**: Handles deprecation of old packages and installation of new ones
- **Rollback Support**: Maintains backups for safe rollback if migration fails
- **State Tracking**: Monitors migration progress and status
- **Logging**: Comprehensive logging for troubleshooting

## Directory Structure

```
/var/lib/distiller-migrator/    # State and configuration
/var/log/distiller-migrator/    # Migration logs
/var/backups/distiller-migrator/ # Rollback backups (preserved on purge)
/usr/share/distiller-migrator/  # Migration scripts and tools
```

## Package Structure

```
debian/
├── control              # Package metadata
├── copyright            # License (MIT)
├── rules                # Build rules
├── changelog            # Version history
├── compat               # Debhelper 14
├── gbp.conf             # git-buildpackage config
├── preinst              # Pre-installation checks
├── postinst             # Post-installation setup
├── prerm                # Pre-removal checks
├── postrm               # Post-removal cleanup
├── distiller-migrator.install        # File installation
├── distiller-migrator.lintian-overrides  # Lintian overrides
└── source/
    └── format           # Source format
```

## Building

```bash
# Build the package
dpkg-buildpackage -us -uc -b

# Check with lintian
lintian -I --show-overrides ../distiller-migrator_*.deb
```

## Installation

```bash
sudo dpkg -i distiller-migrator_1.0.0_all.deb
sudo apt-get install -f
```

## Usage

(Migration tools and commands to be implemented)

```bash
# Run migration
# distiller-migrate --from pamir-ai --to pamir-ai-pkgs

# Check migration status
# distiller-migrate --status

# Rollback migration
# distiller-migrate --rollback
```

## Migration Process

The migrator handles:

1. **Pre-migration checks**
   - Verify system state
   - Backup current configuration
   - Check available disk space

2. **Repository transition**
   - Update APT sources
   - Import new repository keys
   - Update package lists

3. **Package replacement**
   - Map old packages to new packages
   - Handle deprecated packages
   - Install new packages

4. **Post-migration validation**
   - Verify all packages installed correctly
   - Update system configuration
   - Clean up deprecated packages

5. **Rollback (if needed)**
   - Restore from backup
   - Revert repository changes
   - Reinstall previous packages

## State Files

- `/var/lib/distiller-migrator/migration-in-progress` - Migration lock file
- `/var/lib/distiller-migrator/state.json` - Current migration state
- `/var/backups/distiller-migrator/pre-migration/` - Pre-migration backup

## Logs

All migration activities are logged to `/var/log/distiller-migrator/migration.log`

## Development

### Adding Migration Scripts

1. Create scripts in appropriate directory structure
2. Update `debian/distiller-migrator.install` to install them
3. Update documentation

### Testing

```bash
# Test package build
dpkg-buildpackage -us -uc -b

# Test installation
sudo dpkg -i ../distiller-migrator_*.deb
```

## License

MIT License - See debian/copyright for details

## Maintainer

Distiller Team <maintainer@distiller.local>
