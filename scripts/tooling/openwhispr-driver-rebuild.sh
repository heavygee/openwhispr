#!/usr/bin/env bash
# Rebuild worktrees/driver from ~/.config/openwhispr/driver-manifest.yaml
#
# worktrees/driver is READ-ONLY between rebuilds — this script is the only
# supported way to change it.
#
# Usage:
#   openwhispr-driver-rebuild              # rebuild only
#   openwhispr-driver-rebuild --verify     # npm test after merge
#   openwhispr-driver-rebuild --activate   # point active symlink at driver
#
set -euo pipefail

PRIMARY="${OPENWHISPR_PRIMARY:-$HOME/coding/openwhispr}"
WORKTREES="${OPENWHISPR_WORKTREES:-$PRIMARY/worktrees}"
DRIVER="${OPENWHISPR_DRIVER:-$WORKTREES/driver}"
MANIFEST="${OPENWHISPR_DRIVER_MANIFEST:-$HOME/.config/openwhispr/driver-manifest.yaml}"
PARSE="$PRIMARY/scripts/tooling/parse-driver-manifest.mjs"
DRIVER_BRANCH="${OPENWHISPR_DRIVER_BRANCH:-driver/integration}"
UPSTREAM_REPO="${OPENWHISPR_UPSTREAM_REPO:-OpenWhispr/openwhispr}"
FORK_REPO="${OPENWHISPR_FORK_REPO:-heavygee/openwhispr}"
SHARED_ENV="${OPENWHISPR_SHARED_ENV:-$HOME/.config/openwhispr/app.env}"
BUN="${BUN:-$(command -v bun || true)}"
NODE="${NODE:-$(command -v node || true)}"

VERIFY=0
ACTIVATE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --verify) VERIFY=1; shift ;;
        --activate) ACTIVATE=1; shift ;;
        -h|--help)
            sed -n '2,12p' "$0"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 2 ;;
    esac
done

if [[ ! -f "$MANIFEST" ]]; then
    echo "ERROR: manifest not found: $MANIFEST" >&2
    echo "Copy example: mkdir -p ~/.config/openwhispr && cp $PRIMARY/docs/tooling/driver-manifest.example.yaml $MANIFEST" >&2
    exit 1
fi

if [[ ! -f "$PARSE" ]]; then
    echo "ERROR: parser missing: $PARSE" >&2
    exit 1
fi

run_parse() {
    if [[ -n "$BUN" ]]; then
        "$BUN" run "$PARSE" "$MANIFEST"
    elif [[ -n "$NODE" ]]; then
        "$NODE" "$PARSE" "$MANIFEST"
    else
        echo "ERROR: need bun or node to parse manifest" >&2
        exit 1
    fi
}

mkdir -p "$(dirname "$MANIFEST")"
mkdir -p "$WORKTREES"

echo "Fetching remotes..."
git -C "$PRIMARY" fetch upstream
git -C "$PRIMARY" fetch origin

upstream_tip="$(git -C "$PRIMARY" rev-parse upstream/main 2>/dev/null || true)"
if [[ -n "$upstream_tip" ]]; then
    if git -C "$PRIMARY" show-ref --verify --quiet refs/heads/main; then
        behind_main="$(git -C "$PRIMARY" rev-list --count main..upstream/main 2>/dev/null || echo 0)"
        if [[ "${behind_main:-0}" -gt 0 ]]; then
            echo "WARNING: fork main is ${behind_main} commit(s) behind upstream/main" >&2
            echo "         Consider: cd $PRIMARY && git checkout main && git merge --ff-only upstream/main" >&2
        fi
    fi
fi

if [[ -d "$DRIVER" ]] && [[ -n "$(git -C "$DRIVER" status --porcelain 2>/dev/null)" ]]; then
    echo "WARNING: $DRIVER has local changes — rebuild will reset the tree." >&2
fi

if [[ ! -d "$DRIVER" ]]; then
    echo "Creating driver worktree at $DRIVER (branch $DRIVER_BRANCH)..."
    git -C "$PRIMARY" worktree add -b "$DRIVER_BRANCH" "$DRIVER" upstream/main
fi

if [[ -f "$SHARED_ENV" ]]; then
    ln -sfn "$SHARED_ENV" "$DRIVER/.env"
elif [[ -f "$PRIMARY/.env" && ! -e "$DRIVER/.env" ]]; then
    echo "Linking $DRIVER/.env → $PRIMARY/.env (set OPENWHISPR_SHARED_ENV for shared config)" >&2
    ln -sfn "$PRIMARY/.env" "$DRIVER/.env"
fi

manifest_json="$(run_parse)"
base_ref="$(echo "$manifest_json" | jq -r '.base')"
layer_count="$(echo "$manifest_json" | jq '.layers | length')"

if [[ -n "$upstream_tip" && "$base_ref" == "upstream/main" ]]; then
    echo "Base: upstream/main @ $(git -C "$PRIMARY" log -1 --oneline "$upstream_tip")"
fi

echo "Resetting $DRIVER to $base_ref ($layer_count layer(s))..."
git -C "$DRIVER" checkout -B "$DRIVER_BRANCH" "$base_ref"

resolve_merge_ref() {
    local type="$1" ref="$2"
    case "$type" in
        branch|integrate)
            if git -C "$PRIMARY" rev-parse --verify "${ref}^{commit}" >/dev/null 2>&1; then
                echo "$ref"
            elif git -C "$PRIMARY" rev-parse --verify "origin/${ref}^{commit}" >/dev/null 2>&1; then
                echo "origin/${ref}"
            else
                echo "ERROR: layer ref not found: $ref" >&2
                exit 1
            fi
            ;;
        pr)
            local head_branch
            head_branch="$(gh pr view "$ref" --repo "$UPSTREAM_REPO" --json headRefName --jq '.headRefName' 2>/dev/null || true)"
            if [[ -z "$head_branch" || "$head_branch" == "null" ]]; then
                head_branch="$(gh pr view "$ref" --repo "$FORK_REPO" --json headRefName --jq '.headRefName' 2>/dev/null || true)"
            fi
            if [[ -z "$head_branch" || "$head_branch" == "null" ]]; then
                echo "ERROR: could not resolve PR #$ref (tried $UPSTREAM_REPO and $FORK_REPO)" >&2
                exit 1
            fi
            git -C "$PRIMARY" fetch origin "$head_branch" 2>/dev/null || true
            echo "origin/$head_branch"
            ;;
        *)
            echo "ERROR: unknown layer type: $type" >&2
            exit 1
            ;;
    esac
}

for i in $(seq 0 $((layer_count - 1))); do
    type="$(echo "$manifest_json" | jq -r ".layers[$i].type")"
    ref="$(echo "$manifest_json" | jq -r ".layers[$i].ref")"
    merge_ref="$(resolve_merge_ref "$type" "$ref")"

    echo "Layer $((i + 1))/$layer_count: merging $merge_ref ..."
    if ! git -C "$DRIVER" merge --no-edit "$merge_ref"; then
        echo "ERROR: merge conflict merging $merge_ref into $DRIVER_BRANCH" >&2
        echo "Resolve in $DRIVER, commit, or fix manifest order." >&2
        exit 1
    fi
done

echo "Driver HEAD: $(git -C "$DRIVER" log -1 --oneline)"

if [[ "$VERIFY" -eq 1 ]]; then
    echo "Running tests..."
    if [[ ! -d "$DRIVER/node_modules" ]]; then
        echo "Installing dependencies (first driver build)..."
        (cd "$DRIVER" && npm ci)
    fi
    (cd "$DRIVER" && npm test)
fi

echo ""
echo "Driver rebuild complete: $DRIVER @ $(git -C "$DRIVER" rev-parse --short HEAD)"
echo "Manifest: $MANIFEST"
active="${OPENWHISPR_ACTIVE_LINK:-$PRIMARY/active}"
echo "Active checkout: $(readlink -f "$active" 2>/dev/null || echo '(not set)')"

if [[ "$ACTIVATE" -eq 1 ]]; then
    SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
    exec "$SCRIPT_DIR/openwhispr-use-worktree.sh" "$DRIVER"
fi

echo ""
echo "Run app from driver:"
echo "  openwhispr-use-driver"
echo "  cd \"\$(readlink -f $active)\" && npm run dev"
