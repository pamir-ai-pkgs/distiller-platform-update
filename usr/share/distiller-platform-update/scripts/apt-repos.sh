#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=usr/share/distiller-platform-update/lib/shared.sh
source "$(dirname "$SCRIPT_DIR")/lib/shared.sh"
[ "$EUID" -ne 0 ] && {
	echo "Must run as root" >&2
	exit 1
}

cat >/etc/apt/sources.list.d/debian.griffo.io.list <<EOF
deb [signed-by=/etc/apt/trusted.gpg.d/debian.griffo.io.gpg] https://debian.griffo.io/apt $(lsb_release -cs) main
EOF

cp "$DATA_DIR/apt/sources.list.d/pamir-ai.list" /etc/apt/sources.list.d/
cp "$DATA_DIR/apt/keyrings/debian.griffo.io.gpg" /etc/apt/trusted.gpg.d/
cp "$DATA_DIR/apt/keyrings/pamir-ai-archive-keyring.gpg" /usr/share/keyrings/

exit 0
