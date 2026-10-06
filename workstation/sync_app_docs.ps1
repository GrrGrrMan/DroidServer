$TARGET = "192.168.1.35:5555"
$TARGET_IP = "192.168.1.35"
$TARGET_USER = "oppo"
$STAGE = Join-Path $env:TEMP "oppo_app_docs"

Write-Host ">>> Compiling Application Documentation to $STAGE..." -ForegroundColor Cyan

# 1. Initialize local staging buffer
Remove-Item -Recurse -Force $STAGE -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path "$STAGE/modules" -Force | Out-Null

# 2. Base Docsify wrapper
Copy-Item "./docs/index.html" "$STAGE/index.html" -Force
if (Test-Path "./docs/.nojekyll") {
  Copy-Item "./docs/.nojekyll" "$STAGE/.nojekyll" -Force
}

# 3. Generate README.md
@"
# Oppo A91 Workload & Service Registry

> **Scope:** Private, internal application catalog running on port \`:8081\`.
> **Privacy:** LAN and Tailnet out-of-band only. Not published to public GitHub Pages.

---

## Quick Navigation

* ⚙️ **Switch to [Platform Infrastructure Portal (:8080)](http://${TARGET_IP}:8080)** (or [http://oppo-server:8080](http://oppo-server:8080))
* 📦 Review installed services and workload runbooks via the sidebar.
"@ | Set-Content "$STAGE/README.md"

# 4. Harvest docs.md from workloads/ (Excludes all internal meta dirs starting with '_')
$sidebar = @"
* **Navigation**
  * [⚙️ Platform Infrastructure (:8080)](http://${TARGET_IP}:8080)
  * [Overview](README.md)

* **Core Workloads**
"@

# Harvest standard production modules (skips _lib, _local, _TEMPLATE)
Get-ChildItem -Path "./workloads" -Directory | Where-Object { $_.Name -notmatch "^_" } | Sort-Object Name | ForEach-Object {
  $docFile = Join-Path $_.FullName "docs.md"
  if (Test-Path $docFile) {
    $modName = $_.Name
    Copy-Item $docFile "$STAGE/modules/$modName.md"
    $sidebar += "`n  * [$modName](modules/$modName.md)"
  }
}

# Harvest _local private modules if any exist
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

# 5. Ensure webroot exists on phone before SCP
@'
/data/local/bin/chroot-debian.sh "mkdir -p /var/www/oppo-app-docs && chown -R 1000:1000 /var/www/oppo-app-docs"
'@ | adb -s $TARGET shell su

# 6. Transfer via SCP
Write-Host ">>> Transferring app documentation via SCP..." -ForegroundColor Cyan
scp -r "$STAGE/*" "${TARGET_USER}@${TARGET_IP}:/var/www/oppo-app-docs/"

Write-Host ">>> Workload Docs synced. Live at http://${TARGET_IP}:8081 (or http://oppo-server:8081)" -ForegroundColor Green