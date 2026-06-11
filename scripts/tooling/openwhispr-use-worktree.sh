#!/usr/bin/env bash
# Point openwhispr/active at a worktree (run npm run dev from there).
set -euo pipefail

PRIMARY="${OPENWHISPR_PRIMARY:-$HOME/coding/openwhispr}"
ACTIVE_LINK="${OPENWHISPR_ACTIVE_LINK:-$PRIMARY/active}"
SHARED_ENV="${OPENWHISPR_SHARED_ENV:-$HOME/.config/openwhispr/app.env}"
DRIVER="${OPENWHISPR_DRIVER:-$PRIMARY/worktrees/driver}"

WORKTREE="${1:?Usage: openwhispr-use-worktree <path-to-worktree>}"
WORKTREE="$(realpath "$WORKTREE")"

if [[ ! -f "$WORKTREE/package.json" ]] || [[ ! -f "$WORKTREE/main.js" ]]; then
    echo "ERROR: $WORKTREE does not look like an OpenWhispr checkout" >&2
    exit 1
fi

if [[ -f "$SHARED_ENV" ]]; then
    ln -sfn "$SHARED_ENV" "$WORKTREE/.env"
elif [[ -f "$PRIMARY/.env" && ! -e "$WORKTREE/.env" ]]; then
    ln -sfn "$PRIMARY/.env" "$WORKTREE/.env"
fi

if [[ ! -d "$WORKTREE/node_modules" ]]; then
    echo "WARNING: node_modules missing in $WORKTREE — run: cd $WORKTREE && npm ci" >&2
fi

echo "Pointing active → $WORKTREE"
ln -sfn "$WORKTREE" "$ACTIVE_LINK"

echo ""
echo "Active checkout: $(readlink -f "$ACTIVE_LINK")"
echo "HEAD: $(git -C "$WORKTREE" log -1 --oneline)"
echo ""
echo "Start dev:"
echo "  cd \"$(readlink -f "$ACTIVE_LINK")\" && npm run dev"

if [[ "$WORKTREE" == "$(realpath "$DRIVER" 2>/dev/null || echo '')" ]]; then
    echo ""
    echo "Daily driver active."
else
    echo ""
    echo "Restore daily driver: openwhispr-use-driver"
fi
