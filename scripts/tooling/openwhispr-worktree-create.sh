#!/usr/bin/env bash
# Create a PR formulation worktree under worktrees/<name>.
#
# Usage:
#   openwhispr-worktree-create <name> --branch <branch-name> [--after branch:foo] [--after pr:692]
#
set -euo pipefail

PRIMARY="${OPENWHISPR_PRIMARY:-$HOME/coding/openwhispr}"
WORKTREES="${OPENWHISPR_WORKTREES:-$PRIMARY/worktrees}"
UPSTREAM_REPO="${OPENWHISPR_UPSTREAM_REPO:-OpenWhispr/openwhispr}"
FORK_REPO="${OPENWHISPR_FORK_REPO:-heavygee/openwhispr}"
SHARED_ENV="${OPENWHISPR_SHARED_ENV:-$HOME/.config/openwhispr/app.env}"
BASE="${OPENWHISPR_WORKTREE_BASE:-upstream/main}"
NAME=""
BRANCH=""
AFTER=()

usage() {
    sed -n '2,8p' "$0"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --branch) BRANCH="${2:?}"; shift 2 ;;
        --base) BASE="${2:?}"; shift 2 ;;
        --after) AFTER+=("${2:?}"); shift 2 ;;
        -h|--help) usage; exit 0 ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            if [[ -z "$NAME" ]]; then NAME="$1"; shift
            else echo "Unexpected arg: $1" >&2; exit 2; fi
            ;;
    esac
done

[[ -n "$NAME" ]] || { echo "Usage: openwhispr-worktree-create <name> --branch <branch> [--after ref...]" >&2; exit 2; }
[[ -n "$BRANCH" ]] || { echo "ERROR: --branch required" >&2; exit 2; }

PATH_DIR="$WORKTREES/$NAME"

if [[ -e "$PATH_DIR" ]]; then
    echo "ERROR: path already exists: $PATH_DIR" >&2
    exit 1
fi

if git -C "$PRIMARY" show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "ERROR: branch $BRANCH already exists — use a new name or attach existing worktree manually" >&2
    exit 1
fi

mkdir -p "$WORKTREES"

echo "Fetching remotes..."
git -C "$PRIMARY" fetch upstream
git -C "$PRIMARY" fetch origin

echo "Creating worktree $PATH_DIR (branch $BRANCH from $BASE)..."
git -C "$PRIMARY" worktree add -b "$BRANCH" "$PATH_DIR" "$BASE"

if [[ -f "$SHARED_ENV" ]]; then
    ln -sfn "$SHARED_ENV" "$PATH_DIR/.env"
elif [[ -f "$PRIMARY/.env" ]]; then
    ln -sfn "$PRIMARY/.env" "$PATH_DIR/.env"
fi

resolve_after_ref() {
    local spec="$1"
    if [[ "$spec" =~ ^pr:([0-9]+)$ ]]; then
        local pr="${BASH_REMATCH[1]}"
        local head
        head="$(gh pr view "$pr" --repo "$UPSTREAM_REPO" --json headRefName --jq '.headRefName' 2>/dev/null || true)"
        if [[ -z "$head" || "$head" == "null" ]]; then
            head="$(gh pr view "$pr" --repo "$FORK_REPO" --json headRefName --jq '.headRefName' 2>/dev/null || true)"
        fi
        if [[ -z "$head" || "$head" == "null" ]]; then
            echo "ERROR: could not resolve PR #$pr" >&2
            exit 1
        fi
        git -C "$PRIMARY" fetch origin "$head" 2>/dev/null || true
        echo "origin/$head"
    else
        if git -C "$PRIMARY" rev-parse --verify "${spec}^{commit}" >/dev/null 2>&1; then
            echo "$spec"
        elif git -C "$PRIMARY" rev-parse --verify "origin/${spec}^{commit}" >/dev/null 2>&1; then
            echo "origin/${spec}"
        else
            echo "ERROR: --after ref not found: $spec" >&2
            exit 1
        fi
    fi
}

for spec in "${AFTER[@]}"; do
    ref="$(resolve_after_ref "$spec")"
    echo "Merge train: merging $ref into $BRANCH ..."
    if ! git -C "$PATH_DIR" merge --no-edit "$ref"; then
        echo "ERROR: merge conflict for --after $spec" >&2
        echo "Resolve in $PATH_DIR and commit." >&2
        exit 1
    fi
done

echo ""
echo "Worktree ready: $PATH_DIR"
echo "Branch: $BRANCH"
echo "  cd $PATH_DIR"
echo "  git branch --show-current"
echo ""
echo "Activate for dev: openwhispr-use-worktree $PATH_DIR"
