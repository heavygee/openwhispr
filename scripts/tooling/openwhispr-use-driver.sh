#!/usr/bin/env bash
# Point active at the daily-driver soup checkout.
set -euo pipefail

PRIMARY="${OPENWHISPR_PRIMARY:-$HOME/coding/openwhispr}"
DRIVER="${OPENWHISPR_DRIVER:-$PRIMARY/worktrees/driver}"

if [[ ! -d "$DRIVER" ]]; then
    echo "ERROR: driver worktree missing: $DRIVER" >&2
    echo "Run: openwhispr-driver-rebuild" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
exec "$SCRIPT_DIR/openwhispr-use-worktree.sh" "$DRIVER"
