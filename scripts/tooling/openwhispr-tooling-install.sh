#!/usr/bin/env bash
# Install operator scripts to ~/.local/bin
set -euo pipefail

TOOLING="$(cd "$(dirname "$0")" && pwd)"
BIN="${HOME}/.local/bin"
mkdir -p "$BIN"

for script in \
    openwhispr-upstream-status.sh \
    openwhispr-mirror-upstream.sh \
    openwhispr-driver-rebuild.sh \
    openwhispr-worktree-create.sh \
    openwhispr-use-worktree.sh \
    openwhispr-use-driver.sh
do
    base="${script%.sh}"
    src="$TOOLING/$script"
    dest="$BIN/$base"
    chmod +x "$src"
    ln -sfn "$src" "$dest"
    echo "  $dest → $src"
done

chmod +x "$TOOLING/parse-driver-manifest.mjs"

echo ""
echo "Installed. Ensure ~/.local/bin is on PATH."
echo "Docs: $(dirname "$TOOLING")/../docs/tooling/driver-soup.md"
