#!/usr/bin/env bash
# Report how fork main and primary branches relate to upstream/main.
set -euo pipefail

PRIMARY="${OPENWHISPR_PRIMARY:-$HOME/coding/openwhispr}"
UPSTREAM_REPO="${OPENWHISPR_UPSTREAM_REPO:-OpenWhispr/openwhispr}"
FORK_REPO="${OPENWHISPR_FORK_REPO:-heavygee/openwhispr}"

echo "Fetching remotes..."
git -C "$PRIMARY" fetch upstream
git -C "$PRIMARY" fetch origin 2>/dev/null || true

upstream_tip="$(git -C "$PRIMARY" rev-parse upstream/main)"
echo ""
echo "upstream/main @ $(git -C "$PRIMARY" log -1 --oneline upstream/main)"

if git -C "$PRIMARY" show-ref --verify --quiet refs/heads/main; then
    main_tip="$(git -C "$PRIMARY" rev-parse main)"
    behind="$(git -C "$PRIMARY" rev-list --count main..upstream/main)"
    ahead="$(git -C "$PRIMARY" rev-list --count upstream/main..main)"
    echo ""
    echo "fork main @ $(git -C "$PRIMARY" log -1 --oneline main)"
    echo "  behind upstream/main: $behind commit(s)"
    echo "  ahead of upstream/main: $ahead commit(s) (fork-only)"
    if [[ "$behind" -gt 0 ]]; then
        echo ""
        echo "Recent upstream commits not on fork main (last 20):"
        git -C "$PRIMARY" log --oneline main..upstream/main | head -20
        remaining=$((behind > 20 ? behind - 20 : 0))
        if [[ "$remaining" -gt 0 ]]; then
            echo "  ... and $remaining more"
        fi
    fi
    if [[ "$ahead" -gt 0 ]]; then
        echo ""
        echo "Fork-only commits on main:"
        git -C "$PRIMARY" log --oneline upstream/main..main
    fi
fi

current_branch="$(git -C "$PRIMARY" branch --show-current 2>/dev/null || true)"
if [[ -n "$current_branch" && "$current_branch" != "main" ]]; then
    echo ""
    echo "Current branch: $current_branch @ $(git -C "$PRIMARY" log -1 --oneline "$current_branch")"
  behind_ub="$(git -C "$PRIMARY" rev-list --count "$current_branch"..upstream/main 2>/dev/null || echo 0)"
  ahead_ub="$(git -C "$PRIMARY" rev-list --count upstream/main.."$current_branch" 2>/dev/null || echo 0)"
    echo "  vs upstream/main: behind $behind_ub, ahead $ahead_ub"
    if [[ "$ahead_ub" -gt 0 ]]; then
        echo "  Commits on branch not in upstream/main:"
        git -C "$PRIMARY" log --oneline upstream/main.."$current_branch" | head -15
    fi
fi

mirror="${OPENWHISPR_UPSTREAM_MIRROR:-$PRIMARY/worktrees/upstream-main}"
if [[ -d "$mirror/.git" || -f "$mirror/.git" ]]; then
    echo ""
    echo "upstream mirror worktree: $mirror @ $(git -C "$mirror" log -1 --oneline 2>/dev/null || echo '(unknown)')"
fi

driver="${OPENWHISPR_DRIVER:-$PRIMARY/worktrees/driver}"
if [[ -d "$driver/.git" || -f "$driver/.git" ]]; then
    echo "driver worktree: $driver @ $(git -C "$driver" log -1 --oneline 2>/dev/null || echo '(unknown)')"
fi

active="${OPENWHISPR_ACTIVE_LINK:-$PRIMARY/active}"
if [[ -L "$active" ]]; then
    echo "active → $(readlink -f "$active")"
fi

echo ""
echo "Mirror: openwhispr-mirror-upstream"
echo "Rebuild daily driver: openwhispr-driver-rebuild [--verify]"
