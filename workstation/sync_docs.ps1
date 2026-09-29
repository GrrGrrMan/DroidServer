Write-Host ">>> Syncing Docsify files to oppo@192.168.1.35:/var/www/oppo-docs..." -ForegroundColor Cyan
scp -r ./docs/* oppo@192.168.1.35:/var/www/oppo-docs/
Write-Host ">>> Docs synced. Live at http://192.168.1.35:8080 (or http://oppo-server:8080)" -ForegroundColor Green
