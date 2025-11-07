# Bug Fixes - distiller-platform-update

## Issues Fixed

### 1. boot-patcher.sh - Silent failures with `set -e`

**Problem:** Script would exit silently when conditional checks returned false, due to `set -e` behavior with `&&` patterns.

**Locations:**
- Line 89: `[ "$duplicates_found" -gt 0 ] && echo "Commented out..."`
- Line 214: `[ "${#existing_directives[@]}" -gt 0 ] && { ... }`

**Root Cause:**
- When `duplicates_found=0` or `existing_directives` array is empty, the `[ ]` test returns exit code 1
- With `set -e`, any non-zero exit causes immediate script termination
- Script dies before completing boot configuration merge

**Fix:** Changed to `if` statements, which are handled specially by bash and don't trigger `set -e` on false conditions.

```bash
# Before (breaks with set -e)
[ "$duplicates_found" -gt 0 ] && echo "message"

# After (works with set -e)
if [ "$duplicates_found" -gt 0 ]; then
    echo "message"
fi
```

**Impact:** Boot configuration patching now completes successfully on first-time installations.

---

### 2. sudoers-setup.sh - Missing log_success function

**Problem:** Script called `log_success()` function that didn't exist in shared.sh.

**Location:** Line 19

**Root Cause:** Only `log_error()` was defined in shared.sh, causing "command not found" error.

**Fix:**
- Added `log_success()` function to lib/shared.sh
- Changed sudoers-setup.sh validation to use if/else with proper error handling

**Impact:** Sudoers configuration now logs success/failure properly during installation.

---

## Related Issue: distiller-cc Package

### distiller-cc preinst fails during parallel installation

**Problem:** `distiller-cc` package installation fails with "Claude Code not found in PATH" even though Claude Code is installed.

**Location:** distiller-cc debian/preinst script

**Root Cause:**
- preinst script uses `command -v claude` and exits with `exit 1` if not found
- During parallel APT installation, Claude Code may not be in PATH yet
- No dependency relationship ensures `distiller-platform-update` installs before `distiller-cc`
- preinst runs in limited environment where PATH resolution behaves unpredictably

**Current Workaround:** None - installation fails

**Recommended Fix (in distiller-cc package):**

Option 1 - Add dependency:
```debian
Depends: ${misc:Depends},
         distiller-platform-update (>= 2.0.0)
```

Option 2 - Make check non-fatal:
```bash
if ! command -v claude >/dev/null 2>&1; then
    echo "WARNING: Claude Code not found" >&2
    exit 0  # Allow installation to continue
fi
```

Option 3 - Check actual location:
```bash
if [ ! -x "/usr/local/bin/claude" ]; then
    echo "WARNING: Claude Code not installed" >&2
    exit 0
fi
```

**Best Solution:** Combine Option 1 + Option 2 - add dependency AND make check non-fatal.

---

## Testing Notes

- Fixes tested on device 192.168.4.172
- Full update path verified by setting `DISTILLER_PLATFORM_VERSION=1.0.0` in `/etc/distiller-platform-info`
- All update phases (apt-repos, env-vars, user-groups, udev-rules, sudoers, automount, logrotate, boot-patcher, nvm, claude) completed successfully
- Boot configuration merge completed without silent failures

## Files Modified

- `usr/share/distiller-platform-update/lib/shared.sh` - Added log_success()
- `usr/share/distiller-platform-update/scripts/boot-patcher.sh` - Fixed set -e conditional failures
- `usr/share/distiller-platform-update/scripts/sudoers-setup.sh` - Fixed log_success call and error handling
