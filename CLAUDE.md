# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

System configuration updater that brings older Distiller device images up to parity with latest builds. Architecture-independent Debian package that automatically applies platform-level updates during installation/upgrade.

**Package Type**: Debian package (architecture: all)
**Language**: Bash shell scripts
**Target Platform**: ARM64 Linux (Raspberry Pi CM5, Radxa Zero 3/3W, ArmSom CM5 IO)
**Installation Path**: `/usr/share/distiller-platform-update`

## Build Commands

```bash
# Build Debian package (default: arm64)
just build

# Build for specific architecture
just build all        # Architecture-independent
just build arm64      # ARM64 architecture
just build amd64      # x86_64 architecture

# Clean build artifacts
just clean

# Update changelog (git-buildpackage style)
just changelog

# Or manually with dch
dch -i
```

The build process uses `debuild` with parallel compilation and creates `.deb` in `dist/` directory.

## Architecture

### Update Orchestration Flow

The package uses a multi-phase update system triggered by `debian/postinst`:

1. **Platform Detection** (`lib/platform-detect.sh`)
   - Reads `/proc/cpuinfo` and `/proc/device-tree/model` to identify hardware
   - Returns: `cm5`, `radxa-zero3`, `armsom-cm5`, or `unknown`

2. **Version Check** (`lib/update-orchestrator.sh`)
   - Compares `/etc/distiller-platform-info` version with `UPDATE_THRESHOLD_VERSION` (2.0.0)
   - Incremental update path: Only installs Claude Code if missing
   - Full update path: Runs all update phases sequentially

3. **Update Phases** (executed in order):
   - `apt-repos.sh` - APT repository configuration with GPG keys
   - `env-vars.sh` - Environment variables (`DISTILLER_PLATFORM`, `PYTHONPATH`, `LD_LIBRARY_PATH`)
   - `user-groups.sh` - Add distiller user to hardware groups (audio, video, spi, gpio, i2c)
   - `udev-rules.sh` - SD card automount and Pico device rules
   - `sudoers-setup.sh` - Passwordless sudo for hardware access
   - `automount-setup.sh` - PolicyKit configuration for udisks2
   - `logrotate-setup.sh` - Log rotation for `/var/log/distiller-platform-update/`
   - `boot-patcher.sh` - Boot partition configuration (requires reboot)
   - `nvm-install.sh` - NVM + Node.js v20.19.5 for distiller user
   - `claude-code-installer.sh` - Claude Code CLI installation

4. **Version Tracking**
   - Updates `DISTILLER_PLATFORM_VERSION` in `/etc/distiller-platform-info`
   - Stores installation metadata (date, method, platform, configuration flags)

### Boot Configuration Patcher

`boot-patcher.sh` implements intelligent boot file patching with these constraints:

**Marker-Based Block Management**:
- Uses markers `# Distiller CM5 Hardware Configuration` / `# End Distiller CM5 Hardware Configuration`
- Extracts existing Distiller block via `extract_distiller_block()` (returns line range `start:end`)
- Preserves user customizations within block, appends to "User customizations" section

**Duplicate Handling**:
- `comment_out_duplicates()` searches for directives outside Distiller block
- Comments duplicates with `# (Moved to Distiller section)` prefix
- Handles `dtoverlay=`, `dtparam=`, and standard key-value directives differently

**Idempotency**:
- Creates timestamped backups in `/var/backups/distiller-platform-update/boot/`
- Merges new directives from `data/boot/config.additions` with existing block
- Preserves user-added directives not in template

**Section Awareness**:
- Tracks `[section]` headers (e.g., `[cm5]`, `[all]`)
- Directive keys use `section:key` format internally

**Directive Removal**:
- `remove_setting()` removes deprecated settings (e.g., `over_voltage`)
- Optionally removes associated comment lines matching regex pattern

### Shared Library (`lib/shared.sh`)

Common constants and functions used across scripts:

```bash
PLATFORM_INFO="/etc/distiller-platform-info"
UPDATE_THRESHOLD_VERSION="2.0.0"
VERSION_FILE="/usr/share/distiller-platform-update/VERSION"

get_platform_version()      # Read current version from platform info
update_platform_version()   # Update version in platform info
read_version_file()         # Read VERSION file
log_error()                 # Log to /var/log/distiller-platform-update/platform-update.log
log_success()               # Log success messages
```

All scripts source `shared.sh` via:
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shared.sh"
```

**Version Detection Edge Cases**:
- File missing → returns empty string → treated as "0.0.0" → full update
- File exists, no `DISTILLER_PLATFORM_VERSION` line → returns "0.0.0" → full update
- File exists, version < 2.0.0 → full update
- File exists, version >= 2.0.0 → incremental update (Claude Code only if missing)

## File Structure

```
usr/share/distiller-platform-update/
├── lib/
│   ├── shared.sh              # Common functions, constants
│   ├── platform-detect.sh     # Hardware platform detection
│   └── update-orchestrator.sh # Main update orchestration logic
├── scripts/                   # Individual update phase scripts
│   ├── apt-repos.sh
│   ├── boot-patcher.sh
│   ├── env-vars.sh
│   ├── udev-rules.sh
│   ├── user-groups.sh
│   ├── automount-setup.sh
│   ├── sudoers-setup.sh
│   ├── logrotate-setup.sh
│   ├── nvm-install.sh
│   └── claude-code-installer.sh
└── data/                      # Configuration templates and files
    ├── apt/
    │   ├── keyrings/          # GPG keys for repositories
    │   └── sources.list.d/    # APT source lists
    ├── boot/
    │   ├── cmdline.additions  # Kernel command line parameters
    │   └── config.additions   # Boot config directives
    ├── environment/           # Environment variable templates
    ├── polkit-1/              # PolicyKit rules
    ├── udev/rules.d/          # Udev rules
    ├── sudoers.d/             # Sudoers configuration
    └── logrotate.d/           # Logrotate configuration

debian/
├── control                    # Package metadata, dependencies
├── postinst                   # Triggers update-orchestrator.sh
├── postrm                     # Cleanup on removal
└── changelog                  # Version history
```

## Development Guidelines

### Shell Script Quality

All shell scripts should follow these standards:

```bash
# Validate scripts with shellcheck
shellcheck usr/share/distiller-platform-update/scripts/*.sh
shellcheck usr/share/distiller-platform-update/lib/*.sh

# Common patterns to follow
set -e                        # Exit on error
source "$SCRIPT_DIR/shared.sh"  # Use shared library
[ "$EUID" -eq 0 ] || exit 1  # Check root access
log_error "message"           # Consistent error logging
```

### Adding New Update Phases

1. Create script in `usr/share/distiller-platform-update/scripts/`
2. Source `../lib/shared.sh` at top of script
3. Add error handling: `set -e` and appropriate exit codes
4. Validate with `shellcheck` before committing
5. Add script invocation to `lib/update-orchestrator.sh` in correct phase order
6. Make script idempotent - safe to run multiple times
7. Add corresponding flag to `/etc/distiller-platform-info` (e.g., `COMPONENT_CONFIGURED=yes`)

### Modifying Boot Configuration

Edit `usr/share/distiller-platform-update/data/boot/config.additions`:
- Use comments to explain each directive
- Group related directives with section headers `[section]`
- `boot-patcher.sh` will merge changes intelligently on next package upgrade

### Testing Boot Patcher Logic

```bash
# Test on development system (non-destructive)
sudo ./usr/share/distiller-platform-update/scripts/boot-patcher.sh

# Check backup created
ls -la /var/backups/distiller-platform-update/boot/

# Verify changes
diff /var/backups/distiller-platform-update/boot/config.txt.* /boot/firmware/config.txt

# Restore if needed
sudo cp /var/backups/distiller-platform-update/boot/config.txt.* /boot/firmware/config.txt
```

### Version Bumping

```bash
# Automated way (git-buildpackage)
just changelog                # Auto-generate from git log
echo "2.1.0" > VERSION        # Update VERSION file

# Manual way
dch -v 2.1.0-1                # New version (interactive editor)
dch -a "Description"          # Add changelog entry
echo "2.1.0" > VERSION        # Update VERSION file

# Build and test
just build
sudo dpkg -i dist/distiller-platform-update_2.1.0_all.deb
cat /etc/distiller-platform-info  # Verify version updated
```

**Note**: The VERSION file must be kept in sync with debian/changelog version.

### Debugging Update Failures

```bash
# Check platform detection
/usr/share/distiller-platform-update/lib/platform-detect.sh

# View installation logs
journalctl -u dpkg -g "distiller-platform-update"

# Check platform info
cat /etc/distiller-platform-info

# Manual update orchestration (testing)
sudo /usr/share/distiller-platform-update/lib/update-orchestrator.sh

# View update logs
tail -f /var/log/distiller-platform-update/platform-update.log
```

## Key Implementation Patterns

### Idempotent Script Design

All update scripts must be idempotent:

```bash
# Check before modify
if [ ! -f "$TARGET_FILE" ]; then
    cp "$SOURCE_FILE" "$TARGET_FILE"
fi

# Use grep to check existing configuration
if ! grep -q "pattern" "$CONFIG_FILE"; then
    echo "new_config" >> "$CONFIG_FILE"
fi
```

### Safe File Operations

```bash
# Create backups before modification
mkdir -p "$BACKUP_DIR"
cp -a "$ORIGINAL" "$BACKUP_DIR/$(basename $ORIGINAL).$(date +%Y%m%d_%H%M%S)"

# Use temporary files for complex edits
sed 's/pattern/replacement/' "$FILE" > "${FILE}.tmp"
mv "${FILE}.tmp" "$FILE"
```

### Error Handling

```bash
set -e  # Exit on error

# Critical operations
command || {
    log_error "Operation failed"
    exit 1
}

# Non-fatal operations
"$SCRIPTS_DIR/optional-feature.sh" || true
```

### Platform-Specific Logic

```bash
platform=$("$LIB_DIR/platform-detect.sh")
export DISTILLER_PLATFORM="$platform"

case "$platform" in
cm5)
    # Raspberry Pi CM5 specific
    ;;
radxa-zero3)
    # Radxa Zero 3/3W specific
    ;;
armsom-cm5)
    # ArmSom CM5 IO specific
    ;;
*)
    log_error "Unsupported platform: $platform"
    exit 1
    ;;
esac
```

## Critical Constraints

- **Root Required**: All scripts assume `EUID -eq 0` (run via dpkg/apt)
- **Boot Directory**: `/boot/firmware` must exist for boot patching (Raspberry Pi layout)
- **Incremental Updates**: Version < 2.0.0 triggers full update, >= 2.0.0 only updates missing components
- **Backup Safety**: Always create timestamped backups before modifying system files
- **Non-Fatal Helpers**: Developer tools (NVM, Claude Code) use `|| true` to prevent package installation failure
- **Marker Integrity**: Boot patcher relies on exact marker strings - do not modify marker text
- **VERSION Sync**: VERSION file must match debian/changelog version number

## Quick Reference

### Common Debug Commands

```bash
# Check current platform and version
cat /etc/distiller-platform-info
/usr/share/distiller-platform-update/lib/platform-detect.sh

# View update logs
tail -f /var/log/distiller-platform-update/platform-update.log
journalctl -u dpkg -g "distiller-platform-update" --no-pager

# Test individual update phases
sudo /usr/share/distiller-platform-update/scripts/boot-patcher.sh
sudo /usr/share/distiller-platform-update/scripts/apt-repos.sh
sudo /usr/share/distiller-platform-update/lib/update-orchestrator.sh

# Check boot configuration
grep -A 30 "Distiller CM5 Hardware Configuration" /boot/firmware/config.txt
ls -lat /var/backups/distiller-platform-update/boot/

# Validate shell scripts
shellcheck usr/share/distiller-platform-update/**/*.sh
```

### Build and Test Cycle

```bash
# Standard workflow
just clean
just changelog                # If using git-buildpackage
echo "2.1.0" > VERSION       # Update version
just build
sudo dpkg -i dist/distiller-platform-update_*.deb

# Verify installation
cat /etc/distiller-platform-info
tail /var/log/distiller-platform-update/platform-update.log
```
