param (
  [ValidateSet("all", "platform", "app")]
  [string]$Target = "all"
)

$TARGET_IP = "192.168.1.35"
$TARGET_ADB = "${TARGET_IP}:5555"
$TARGET_USER = "oppo"

# ===========================================================================
# 1. Platform Infrastructure Portal (:8080 -> /var/www/oppo-docs)
# ===========================================================================
if ($Target -eq "all" -or $Target -eq "platform") {
  Write-Host ">>> [Platform Docs] Ensuring remote webroot exists on phone..." -ForegroundColor Cyan
  @'
  /data/local/bin/chroot-debian.sh "mkdir -p /var/www/oppo-docs && chown -R 1000:1000 /var/www/oppo-docs"
'@ | adb -s $TARGET_ADB shell su

  Write-Host ">>> [Platform Docs] Syncing ./docs to ${TARGET_USER}@${TARGET_IP}:/var/www/oppo-docs..." -ForegroundColor Cyan
  scp -r ./docs/* "${TARGET_USER}@${TARGET_IP}:/var/www/oppo-docs/"
  Write-Host ">>> [Platform Docs] Live at http://${TARGET_IP}:8080 (or http://oppo-server:8080)" -ForegroundColor Green
}

# ===========================================================================
# 2. Workload & Service Registry (:8081 -> /var/www/oppo-app-docs)
# ===========================================================================
if ($Target -eq "all" -or $Target -eq "app") {
  $STAGE = Join-Path $env:TEMP "oppo_app_docs"
  Write-Host ">>> [App Docs] Compiling Workload Registry staging buffer at $STAGE..." -ForegroundColor Cyan

  Remove-Item -Recurse -Force $STAGE -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Path "$STAGE/modules" -Force | Out-Null

  # Copy base Docsify wrappers
  Copy-Item "./docs/index.html" "$STAGE/index.html" -Force
  if (Test-Path "./docs/.nojekyll") {
    Copy-Item "./docs/.nojekyll" "$STAGE/.nojekyll" -Force
  }

  # Build App Registry landing page
  $readmeTemplate = @'
# Oppo A91 Workload & Service Registry

> **Scope:** Private internal application catalog running on port `:8081`.  
> **Privacy:** LAN and Tailnet out-of-band only. Not published to public GitHub Pages.

---

## Quick Navigation

* ⚙️ **Switch to [Platform Infrastructure Portal (:8080)](http://__TARGET_IP__:8080)** (or [http://oppo-server:8080](http://oppo-server:8080))
* 📦 Review installed services and workload runbooks via the sidebar.
'@
  $readmeTemplate.Replace('__TARGET_IP__', $TARGET_IP) | Set-Content "$STAGE/README.md"

  # Build Dynamic Sidebar
  $sidebar = @"
* **Navigation**
  * [⚙️ Platform Infrastructure (:8080)](http://${TARGET_IP}:8080)
  * [Overview](README.md)

* **Core Workloads**
"@

  # Harvest production workloads (ignores internal meta directories prefixed with '_')
  Get-ChildItem -Path "./workloads" -Directory | Where-Object { $_.Name -notmatch "^_" } | Sort-Object Name | ForEach-Object {
    $docFile = Join-Path $_.FullName "docs.md"
    if (Test-Path $docFile) {
      $modName = $_.Name
      Copy-Item $docFile "$STAGE/modules/$modName.md"
      $sidebar += "`n  * [$modName](modules/$modName.md)"
    }
  }

  # Harvest private local workloads (_local/)
  $localDirs = Get-ChildItem -Path "./workloads/_local" -Directory -ErrorAction SilentlyContinue
  if ($localDirs -and $localDirs.Count -gt 0) {
    $sidebar += "`n`n* **Local & Private Modules**"
    $localDirs | Sort-Object Name | ForEach-Object {
      $docFile = Join-Path $_.FullName "docs.md"
      if (Test-Path $docFile) {
        $modName = $_.Name
        Copy-Item $docFile "$STAGE/modules/local_$modName.md"
        $sidebar += "`n  * [local/$modName](modules/local_$modName.md)"
      }
    }
  }

  $sidebar | Set-Content "$STAGE/_sidebar.md"

  Write-Host ">>> [App Docs] Ensuring remote webroot exists on phone..." -ForegroundColor Cyan
  @'
  /data/local/bin/chroot-debian.sh "mkdir -p /var/www/oppo-app-docs && chown -R 1000:1000 /var/www/oppo-app-docs"
'@ | adb -s $TARGET_ADB shell su

  Write-Host ">>> [App Docs] Syncing registry to ${TARGET_USER}@${TARGET_IP}:/var/www/oppo-app-docs..." -ForegroundColor Cyan
  scp -r "$STAGE/*" "${TARGET_USER}@${TARGET_IP}:/var/www/oppo-app-docs/"
  Write-Host ">>> [App Docs] Live at http://${TARGET_IP}:8081 (or http://oppo-server:8081)" -ForegroundColor Green

  Remove-Item -Recurse -Force $STAGE -ErrorAction SilentlyContinue
}

Write-Host ">>> Documentation sync complete." -ForegroundColor Green