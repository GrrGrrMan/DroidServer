param (
  [string]$Target = "all"
)

# Default parameters
$DEVICE_IP = "192.168.1.35"
$ADB_PORT = "5555"
$SERVER_USER = "oppo"

# Load local config.env if present
$ConfigFile = Join-Path $PSScriptRoot "..\config.env"
if (Test-Path $ConfigFile) {
  Get-Content $ConfigFile | ForEach-Object {
    if ($_ -match '^\s*([^#=]+)\s*=\s*"?([^"#]*)"?') {
      $k = $matches[1].Trim()
      $v = $matches[2].Trim()
      if ($k -eq "DEVICE_IP") { $DEVICE_IP = $v }
      if ($k -eq "ADB_PORT") { $ADB_PORT = $v }
      if ($k -eq "SERVER_USER") { $SERVER_USER = $v }
    }
  }
}

$TARGET_ADB = "${DEVICE_IP}:${ADB_PORT}"
$WEBROOT = "/var/www/docs"
$STAGE = Join-Path $env:TEMP "droidserver_docs_stage"

Write-Host ">>> Compiling Documentation Overlay at $STAGE..." -ForegroundColor Cyan

Remove-Item -Recurse -Force $STAGE -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$STAGE" -Force | Out-Null

# Copy base public docs
Copy-Item "./docs/*" "$STAGE/" -Recurse -Force
New-Item -ItemType Directory -Path "$STAGE/apps" -Force | Out-Null

# Harvest workload documentation into apps/ subfolder
$sidebarApps = "`n`n* **Applications & Workloads**"
Get-ChildItem -Path "./workloads" -Directory | Where-Object { $_.Name -notmatch "^_" } | Sort-Object Name | ForEach-Object {
  $docFile = Join-Path $_.FullName "docs.md"
  if (Test-Path $docFile) {
    $modName = $_.Name
    Copy-Item $docFile "$STAGE/apps/${modName}.md" -Force
    $sidebarApps += "`n  * [$modName](apps/${modName}.md)"
  }
}

# Harvest private local modules (_local/)
$localDirs = Get-ChildItem -Path "./workloads/_local" -Directory -ErrorAction SilentlyContinue
if ($localDirs -and $localDirs.Count -gt 0) {
  $sidebarApps += "`n`n* **Private Local Modules**"
  $localDirs | Sort-Object Name | ForEach-Object {
    $docFile = Join-Path $_.FullName "docs.md"
    if (Test-Path $docFile) {
      $modName = $_.Name
      Copy-Item $docFile "$STAGE/apps/local_${modName}.md" -Force
      $sidebarApps += "`n  * [local/$modName](apps/local_${modName}.md)"
    }
  }
}

# Append dynamic app overlay to phone's sidebar
Add-Content -Path "$STAGE/_sidebar.md" -Value $sidebarApps -Encoding UTF8

Write-Host ">>> Ensuring remote webroot $WEBROOT exists on phone..." -ForegroundColor Cyan
@'
/data/local/bin/chroot-debian.sh "mkdir -p /var/www/docs && chown -R 1000:1000 /var/www/docs"
'@ | adb -s $TARGET_ADB shell su

Write-Host ">>> Syncing documentation overlay to ${SERVER_USER}@${DEVICE_IP}:${WEBROOT}..." -ForegroundColor Cyan
scp -r "$STAGE/*" "${SERVER_USER}@${DEVICE_IP}:${WEBROOT}/"
Write-Host ">>> Documentation Portal live at http://${DEVICE_IP}:8080 (or http://oppo-server:8080)" -ForegroundColor Green

Remove-Item -Recurse -Force $STAGE -ErrorAction SilentlyContinue