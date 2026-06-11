# OpenWhispr daily-driver Windows build (background-safe, idempotent).
#
# Designed to be invoked detached over SSH via a Windows Scheduled Task:
#   schtasks /Create /TN OpenWhisprDriverBuild /SC ONCE /ST 23:59 ^
#     /TR "powershell -ExecutionPolicy Bypass -File <path-to-this-script>" /F
#   schtasks /Run /TN OpenWhisprDriverBuild
#
# Logs to %TEMP%\driver-build.log; writes %TEMP%\driver-build.done with OK or
# FAIL: <step> for completion polling.
#
# Prereqs: see docs/tooling/driver-soup.md "Windows daily-driver build".

$ErrorActionPreference = 'Continue'
$LOG = "$env:USERPROFILE\AppData\Local\Temp\driver-build.log"
$DONE_MARKER = "$env:USERPROFILE\AppData\Local\Temp\driver-build.done"
$repo = if ($env:OPENWHISPR_PRIMARY) { $env:OPENWHISPR_PRIMARY } else { 'H:\home\heavygee\coding\openwhispr' }
$driver = if ($env:OPENWHISPR_DRIVER) { $env:OPENWHISPR_DRIVER } else { "$repo\worktrees\driver" }

function Log([string]$msg) {
    $ts = Get-Date -Format 'HH:mm:ss'
    Add-Content -Path $LOG -Value "[$ts] $msg"
}

Set-Content -Path $LOG -Value "[$(Get-Date -Format 'HH:mm:ss')] === Driver build started ===`n"
Remove-Item -ErrorAction SilentlyContinue $DONE_MARKER

# PATH: winget MSI installs don't always register on fresh non-login shells.
$pythonDir = "$env:LOCALAPPDATA\Programs\Python\Python312"
if (Test-Path "$pythonDir\python.exe") { $env:Path = "$pythonDir;$pythonDir\Scripts;" + $env:Path }
$nodeDir = 'C:\Program Files\nodejs'
if (Test-Path "$nodeDir\node.exe") { $env:Path = "$nodeDir;" + $env:Path }
$gitBin = 'C:\Program Files\Git\bin'
if (Test-Path "$gitBin\bash.exe") { $env:Path = "$gitBin;$gitBin\..\cmd;" + $env:Path }
$gitUsrBin = 'C:\Program Files\Git\usr\bin'
if (Test-Path "$gitUsrBin\bzip2.exe") { $env:Path = "$gitUsrBin;" + $env:Path }
$gitMinGW = 'C:\Program Files\Git\mingw64\bin'
if (Test-Path $gitMinGW) { $env:Path = "$gitMinGW;" + $env:Path }

# Disable code signing during build (no certs; daily-driver is unsigned).
$env:CSC_IDENTITY_AUTO_DISCOVERY = 'false'
$env:CSC_LINK = ''
$env:WIN_CSC_LINK = ''

Log "PATH initialized"
Log "node $((& node --version) 2>&1)"
Log "npm  $((& npm --version) 2>&1)"
Log "python $((& python --version) 2>&1)"

if (-not (Test-Path $driver)) {
    Log "Driver worktree not found: $driver"
    Set-Content -Path $DONE_MARKER -Value "FAIL: driver worktree missing"
    exit 1
}
Set-Location $driver
Log "cwd: $((Get-Location).Path)"

function Run-Step([string]$label, [scriptblock]$action) {
    Log ""
    Log "=== STEP: $label ==="
    $start = Get-Date
    try {
        & $action *>&1 | ForEach-Object { Add-Content -Path $LOG -Value $_ }
        $rc = $LASTEXITCODE
    } catch {
        Add-Content -Path $LOG -Value ("EXCEPTION: " + $_.Exception.Message)
        $rc = 1
    }
    $dur = (Get-Date) - $start
    Log ("STEP $label exit=$rc duration=$([int]$dur.TotalSeconds)s")
    if ($rc -ne 0) {
        Set-Content -Path $DONE_MARKER -Value "FAIL: $label (exit=$rc)"
        Log "BUILD ABORTED on step: $label"
        exit 1
    }
}

# Skip npm ci if node_modules is current (saves ~1 min on every rebuild)
$nm = Join-Path $driver 'node_modules'
$nmMarker = Join-Path $nm '.package-lock.json'
$pkgLock = Join-Path $driver 'package-lock.json'
if ((Test-Path $nmMarker) -and (Test-Path $pkgLock) -and ((Get-Item $nmMarker).LastWriteTime -ge (Get-Item $pkgLock).LastWriteTime)) {
    Log "=== STEP: npm ci  (skipped: node_modules up-to-date) ==="
} else {
    Run-Step 'npm ci'             { & npm ci 2>&1 }
}

Run-Step 'compile:native'     { & npm run compile:native 2>&1 }
Run-Step 'prebuild:win'       { & npm run prebuild:win 2>&1 }
Run-Step 'build:renderer'     { & npm run build:renderer 2>&1 }

# Build a driver-only electron-builder config: drop azureSignOptions (no certs)
# and `publish` (no upload). Doing this in JSON instead of via `--config.win.azureSignOptions=null`
# CLI flag, which electron-builder 26.x parses as the literal string "null" and rejects.
$ebSrc = Join-Path $driver 'electron-builder.json'
$ebDriver = Join-Path $driver 'electron-builder.driver.json'
$cfg = Get-Content $ebSrc -Raw | ConvertFrom-Json
if ($cfg.win.PSObject.Properties.Name -contains 'azureSignOptions') {
    $cfg.win.PSObject.Properties.Remove('azureSignOptions')
}
if ($cfg.PSObject.Properties.Name -contains 'publish') {
    $cfg.PSObject.Properties.Remove('publish')
}
$cfg | ConvertTo-Json -Depth 100 | Set-Content -Path $ebDriver -Encoding UTF8
Log "Wrote driver electron-builder config: $ebDriver (signing + publish stripped)"

Run-Step 'electron-builder dir' { & npx electron-builder --config electron-builder.driver.json --win --dir --publish=never 2>&1 }

Log ""
Log "=== Build artifacts ==="
$dist = Join-Path $driver 'dist'
if (Test-Path $dist) {
    Get-ChildItem $dist -Force -ErrorAction SilentlyContinue | Select-Object Name, @{n='SizeMB';e={if($_.PSIsContainer){[math]::Round((Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum/1MB,1)}else{[math]::Round($_.Length/1MB,2)}}} | ForEach-Object { Log ("  " + $_.Name + "  " + $_.SizeMB + " MB") }
    $unpacked = Join-Path $dist 'win-unpacked'
    if (Test-Path $unpacked) {
        $exe = Get-ChildItem $unpacked -Filter '*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($exe) { Log ("EXE: " + $exe.FullName) }
    }
}
Log ""
Log "=== Build complete ==="
Set-Content -Path $DONE_MARKER -Value "OK"
