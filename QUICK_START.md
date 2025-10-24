# distiller-migrator Quick Start

## Build the Package

```bash
cd ~/projects/distiller-migrator
dpkg-buildpackage -us -uc -b
```

## Install

```bash
sudo dpkg -i ../distiller-migrator_1.0.0_all.deb
```

## Package Purpose

Migration tool for transitioning from:
- **Old**: pamir-ai organization packages
- **New**: pamir-ai-pkgs organization packages

## Key Features

- Repository configuration updates
- Package deprecation handling
- Rollback capabilities
- State tracking and logging

## Directories Created

- `/var/lib/distiller-migrator/` - State files
- `/var/log/distiller-migrator/` - Logs
- `/var/backups/distiller-migrator/` - Backups (preserved on purge)
- `/usr/share/distiller-migrator/` - Migration scripts

## Implementation TODO

This is a skeleton package. You'll need to implement:

1. Migration scripts (`usr/share/distiller-migrator/`)
2. CLI tool (`usr/bin/distiller-migrate`)
3. Migration logic (Python scripts)
4. Repository configuration handlers
5. Package mapping definitions

## Package Details

- **Section**: admin
- **Priority**: optional
- **Architecture**: all
- **Standards**: Debian Trixie (Policy 4.7.2, debhelper 14)
- **License**: MIT

## Next Steps

1. Implement migration logic
2. Create CLI tool
3. Add tests
4. Update .install file to include actual scripts
5. Build and test
