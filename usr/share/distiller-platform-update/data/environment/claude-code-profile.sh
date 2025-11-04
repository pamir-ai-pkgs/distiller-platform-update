#!/bin/sh
# Claude Code CLI path configuration
# This file is installed to /etc/profile.d/ to ensure claude binary is accessible to all users

# Add /usr/local/bin to PATH if not already present
case ":$PATH:" in
    *:/usr/local/bin:*)
        # Already in PATH
        ;;
    *)
        # Add to PATH
        export PATH="/usr/local/bin:$PATH"
        ;;
esac
