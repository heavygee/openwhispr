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

---

## Windows daily-driver build

Same workflow, run via Git Bash + PowerShell. Layout uses a real path on `H:` (no `~` symlink shenanigans):

```
H:\home\heavygee\coding\openwhispr\                    primary
H:\home\heavygee\coding\openwhispr\worktrees\driver\   soup
%USERPROFILE%\.config\openwhispr\driver-manifest.yaml  manifest (Git Bash $HOME = %USERPROFILE%)
```

### One-time prereqs

- **Node 24 LTS** (`>=24` per package.json): `winget install --id OpenJS.NodeJS.LTS`
- **Python 3.12** (node-gyp / `better-sqlite3` native build): `winget install Python.Python.3.12`
- **jq** (manifest parsing): `winget install jqlang.jq`
- **Git for Windows** (provides Git Bash, `bash`, `bzip2`): `winget install Git.Git`
- **Visual Studio Build Tools 2022** with C++ workload (some prebuilds compile from source). Already present on most dev boxes.
- **Windows Developer Mode** (admin, registry):

```powershell
New-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -Force | Out-Null
Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' \
    -Name 'AllowDevelopmentWithoutDevLicense' -Type DWord -Value 1
```

  Required because `electron-builder` extracts `winCodeSign/<id>.7z` which contains macOS dylib symlinks - non-admin Windows refuses `CreateSymbolicLink` without Developer Mode and the build dies before signing even starts. Toggling this once is fine.

### Bootstrap

```bash
cd /h/home/heavygee/coding
git clone -o origin git@github.com:heavygee/openwhispr.git
cd openwhispr
git remote add upstream https://github.com/OpenWhispr/openwhispr.git
git fetch --all --tags
mkdir -p "$HOME/.config/openwhispr"
cp docs/tooling/driver-manifest.example.yaml "$HOME/.config/openwhispr/driver-manifest.yaml"
# edit the manifest, then:
bash scripts/tooling/openwhispr-driver-rebuild.sh
```

### Build (read-only on driver/integration)

The CLI flag `--config.win.azureSignOptions=null` is broken under electron-builder 26.x (passes the literal string `"null"` which fails schema validation). Pre-process `electron-builder.json` into a driver-only override config that drops `azureSignOptions` and `publish` cleanly, then point electron-builder at that file.

A turnkey script that handles PATH, env vars, the override config, signing-skip, and detached background execution lives in `scripts/tooling/win/driver-build.ps1`. Manual fallback:

```powershell
# In Git Bash inside the driver worktree, or in PowerShell:
cd H:\home\heavygee\coding\openwhispr\worktrees\driver
$env:CSC_IDENTITY_AUTO_DISCOVERY = 'false'
$env:Path = 'C:\Program Files\Git\usr\bin;C:\Program Files\Git\mingw64\bin;' + $env:Path  # for `bzip2`

npm ci
npm run compile:native
npm run prebuild:win    # downloads whisper-cpp / sherpa / qdrant / etc
npm run build:renderer

# Strip Azure signing + publish from config -> driver override file
$cfg = Get-Content electron-builder.json -Raw | ConvertFrom-Json
$cfg.win.PSObject.Properties.Remove('azureSignOptions')
$cfg.PSObject.Properties.Remove('publish')
$cfg | ConvertTo-Json -Depth 100 | Set-Content -Path electron-builder.driver.json -Encoding UTF8

npx electron-builder --config electron-builder.driver.json --win --dir --publish=never
# output: dist\win-unpacked\OpenWhispr.exe (~213 MB exe, ~720 MB unpacked dir)
```

### Long builds over SSH (background)

Don't trust PowerShell `Start-Process` for true detachment over SSH - silent vanish is common. Use a Windows scheduled task instead:

```powershell
schtasks /Create /TN OpenWhisprDriverBuild /SC ONCE /ST 23:59 /TR `
  "powershell -ExecutionPolicy Bypass -File C:\Users\HeavyGee\AppData\Local\Temp\driver-build.ps1" /F
schtasks /Run /TN OpenWhisprDriverBuild
# tail %TEMP%\driver-build.log to monitor
```

Reference build script: `scripts/tooling/win/driver-build.ps1`. It logs to `%TEMP%\driver-build.log` and writes `%TEMP%\driver-build.done` (`OK` / `FAIL: <step>`) for completion polling. It also skips `npm ci` when `node_modules\.package-lock.json` is newer than `package-lock.json` so reruns are fast.

### userData survives swaps

Electron resolves userData from `productName` -> `%APPDATA%\OpenWhispr`. Any build of OpenWhispr (NSIS-installed, daily-driver unpacked, or `npm run dev`) reads/writes the same dir. Models, transcript history, and settings persist across NSIS uninstall, install swap, and rebuild. Only manual `Remove-Item -Recurse -Force "$env:APPDATA\OpenWhispr"` wipes them.

### Replacing an existing install

If a NSIS-installed OpenWhispr is already on the box (e.g. `H:\Apps\OpenWhispr`):

```powershell
# Silent uninstall (cleans registry + start menu shortcuts + install dir):
& 'H:\Apps\OpenWhispr\Uninstall OpenWhispr.exe' /S /currentuser
# Verify nothing under HKCU:\...\Uninstall\* still has DisplayName like 'OpenWhispr*'
# Wipe stale build artifacts elsewhere (e.g. E:\OpenWhispr from older dev experiments)
Remove-Item -Recurse -Force E:\OpenWhispr
```

Recreate shortcuts pointing at the daily driver:

```powershell
$exe = 'H:\home\heavygee\coding\openwhispr\worktrees\driver\dist\win-unpacked\OpenWhispr.exe'
$ws = New-Object -COM WScript.Shell
foreach ($lnk in @(
  "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\OpenWhispr (driver).lnk",
  "$env:USERPROFILE\Desktop\OpenWhispr.lnk"
)) {
  $sh = $ws.CreateShortcut($lnk)
  $sh.TargetPath = $exe
  $sh.WorkingDirectory = (Split-Path $exe -Parent)
  $sh.IconLocation = "$exe,0"
  $sh.Description = 'OpenWhispr (daily driver build)'
  $sh.Save()
}
```

### Auto-update is irrelevant for daily-driver

`electron-updater` is a runtime dependency, but the production driver build never publishes (`publish` block stripped above) and the unpacked dist has no signing certificate, so the in-app updater check will fail silently or 404 against upstream's release feed. That's fine - rebuild via `openwhispr-driver-rebuild` + `npm run build:win` is the update path.

### Common Windows build failures

- **`tar: Can't initialize filter; unable to run program "bzip2 -d"`** during `prebuild:win` -> `bzip2.exe` not on PATH. Add `C:\Program Files\Git\usr\bin`.
- **`Cannot create symbolic link : A required privilege is not held by the client`** during electron-builder's `winCodeSign` extract -> Developer Mode off; see prereqs.
- **`configuration.win.azureSignOptions should be ... null`** schema error -> the `--config.win.azureSignOptions=null` CLI flag is broken in electron-builder 26.x. Strip via the override-config approach above.
- **`MISSING_EXPORT` during build:renderer for a renamed upstream symbol** -> a layer branch is referencing an upstream API that was renamed. Rebase the layer (see "Rebasing fork features onto upstream").
