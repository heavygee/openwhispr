# Daily Driver + Worktrees (OpenWhispr)

Operator layout — everything under `~/coding/openwhispr`:

```
~/coding/openwhispr/                 primary checkout (feature branches, upstream mirror commands)
~/coding/openwhispr/worktrees/
    upstream-main/                   clean upstream/main mirror (read-only reference)
    driver/                          daily-driver soup (manifest merges)
    <name>/                          one worktree per PR / experiment
~/coding/openwhispr/active           symlink → tree you run `npm run dev` from (gitignored)
```

Remotes:

| Remote   | Repo                      | Role        |
|----------|---------------------------|-------------|
| upstream | OpenWhispr/openwhispr     | OSS mainline |
| origin   | heavygee/openwhispr       | Fork        |

---

## Quick commands

```bash
openwhispr-upstream-status          # what's new on upstream/main vs fork main
openwhispr-mirror-upstream          # refresh worktrees/upstream-main
openwhispr-driver-rebuild --verify  # rebuild soup from manifest
openwhispr-use-driver               # point active → driver (restart app manually)
openwhispr-use-worktree worktrees/upstream-main
```

Scripts live in `scripts/tooling/`; install once:

```bash
~/coding/openwhispr/scripts/tooling/openwhispr-tooling-install.sh
```

---

## Daily driver (soup)

**Manifest:** `~/.config/openwhispr/driver-manifest.yaml` (copy from `driver-manifest.example.yaml`)

```yaml
base: upstream/main
layers:
  - branch: feat/quick-spoken-note
  - pr: 835
```

Layers merge **in order** onto branch `driver/integration` inside `worktrees/driver`.

### Read-only driver tree

**`worktrees/driver` is read-only between rebuilds.** Only `openwhispr-driver-rebuild` may change it.

```bash
# 1. Edit ~/.config/openwhispr/driver-manifest.yaml
# 2. Rebuild (resets to base + merges manifest)
openwhispr-driver-rebuild --verify
# 3. Swing active checkout when ready
openwhispr-use-driver
```

**Forbidden on driver:** hand-edits, `cp` from other trees, local commits. Uncommitted changes block rebuild.

**To run a single PR branch without touching driver:** `openwhispr-worktree-create my-pr --branch feat/foo` then `openwhispr-use-worktree worktrees/my-pr`.

### Shared `.env`

Worktrees symlink `.env` → `~/.config/openwhispr/app.env`. Copy your primary `.env` there once:

```bash
mkdir -p ~/.config/openwhispr
cp ~/coding/openwhispr/.env ~/.config/openwhispr/app.env   # if you use repo .env
```

---

## PR / feature worktrees

Never file upstream PRs from `worktrees/driver`. Use dedicated trees:

```bash
openwhispr-worktree-create quick-note --branch feat/quick-spoken-note
openwhispr-worktree-create stacked --branch feat/on-top --after feat/quick-spoken-note
openwhispr-worktree-create from-pr --branch fix/foo --after pr:835
```

Creates `worktrees/<name>/` from `upstream/main` (or `--base`), optional `--after` merge train.

Before every commit / `gh pr create`:

```bash
pwd && git branch --show-current
```

---

## Rebasing fork features onto upstream

If a layer was branched from stale fork `main`, `openwhispr-driver-rebuild` will conflict. Rebase first:

```bash
openwhispr-worktree-create quick-note-rebased --branch feat/quick-spoken-note-rebased
cd ~/coding/openwhispr/worktrees/quick-note-rebased
git merge feat/quick-spoken-note   # or cherry-pick; resolve conflicts vs upstream/main
# push branch, then manifest: - branch: feat/quick-spoken-note-rebased
```

Keep dirty WIP on the **primary** checkout; use worktrees for integration.

## When upstream moves

1. `openwhispr-mirror-upstream` and/or fast-forward fork `main`:  
   `cd ~/coding/openwhispr && git checkout main && git merge --ff-only upstream/main`
2. Edit manifest (drop merged PRs, add new layers)
3. `openwhispr-driver-rebuild --verify`
4. Smoke: `cd "$(readlink -f ~/coding/openwhispr/active)" && npm test` (or run app)

---

## Environment overrides

| Variable | Default |
|----------|---------|
| `OPENWHISPR_PRIMARY` | `~/coding/openwhispr` |
| `OPENWHISPR_WORKTREES` | `$PRIMARY/worktrees` |
| `OPENWHISPR_DRIVER` | `$WORKTREES/driver` |
| `OPENWHISPR_UPSTREAM_MIRROR` | `$WORKTREES/upstream-main` |
| `OPENWHISPR_DRIVER_MANIFEST` | `~/.config/openwhispr/driver-manifest.yaml` |
| `OPENWHISPR_UPSTREAM_REPO` | `OpenWhispr/openwhispr` |
| `OPENWHISPR_FORK_REPO` | `heavygee/openwhispr` |
| `OPENWHISPR_SHARED_ENV` | `~/.config/openwhispr/app.env` |

---

## Scripts

| Command | Purpose |
|---------|---------|
| `openwhispr-upstream-status` | Report fork vs upstream divergence |
| `openwhispr-mirror-upstream` | Reset `worktrees/upstream-main` to `upstream/main` |
| `openwhispr-driver-rebuild` | Rebuild soup from manifest |
| `openwhispr-worktree-create` | New PR worktree under `worktrees/` |
| `openwhispr-use-worktree` | Point `active` symlink at a tree |
| `openwhispr-use-driver` | Point `active` at daily driver |
