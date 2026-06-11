#!/usr/bin/env bash
# Maintain a clean upstream/main worktree at worktrees/upstream-main.
set -euo pipefail

PRIMARY="${OPENWHISPR_PRIMARY:-$HOME/coding/openwhispr}"
WORKTREES="${OPENWHISPR_WORKTREES:-$PRIMARY/worktrees}"
MIRROR="${OPENWHISPR_UPSTREAM_MIRROR:-$WORKTREES/upstream-main}"
MIRROR_BRANCH="${OPENWHISPR_MIRROR_BRANCH:-mirror/upstream-main}"

mkdir -p "$WORKTREES"

echo "Fetching upstream..."
git -C "$PRIMARY" fetch upstream

upstream_tip="$(git -C "$PRIMARY" rev-parse upstream/main)"
echo "upstream/main → $(git -C "$PRIMARY" log -1 --oneline "$upstream_tip")"

if [[ ! -d "$MIRROR" ]]; then
    echo "Creating mirror worktree at $MIRROR ..."
    git -C "$PRIMARY" worktree add -b "$MIRROR_BRANCH" "$MIRROR" upstream/main
else
    echo "Resetting $MIRROR to upstream/main ..."
    git -C "$MIRROR" fetch upstream 2>/dev/null || git -C "$PRIMARY" fetch upstream
    git -C "$MIRROR" checkout -B "$MIRROR_BRANCH" upstream/main
fi

link_shared_env() {
    local tree="$1"
    local shared="${OPENWHISPR_SHARED_ENV:-$HOME/.config/openwhispr/app.env}"
    if [[ -f "$shared" && ! -e "$tree/.env" ]]; then
        ln -sfn "$shared" "$tree/.env"
    fi
}

link_shared_env "$MIRROR"

echo "Mirror ready: $MIRROR @ $(git -C "$MIRROR" log -1 --oneline)"
