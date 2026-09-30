# Docs_Portal (Sub-Tab: 01_SERVICES)

> **Scope:** Client-side Docsify single-page documentation engine served via lightweight asynchronous HTTP server with real-time search, Prism syntax highlighting, and 1-click code copying.  
> **Port / Endpoint:** `TCP :8080` | Local Health Check: `curl -sI http://127.0.0.1:8080 | head -n 1`  
> **Lifecycle Supervisor:** PM2 under user `oppo` (UID 1000)

---

## 1. LIFECYCLE (OPERATIONS)

Supervised via PM2 under the unprivileged `oppo` user. Standard output and error logs stream exclusively to RAM (`/dev/shm`) to eliminate write wear on soldered UFS flash.

### Start Daemon

**`[Debian:oppo$]`**
```bash
pm2 start /usr/bin/python3 --name "docs-portal" \
  --output /dev/shm/docs-portal.log \
  --error /dev/shm/docs-portal.err \
  --restart-delay 5000 \
  -- -m http.server 8080 --directory /var/www/oppo-docs
```

### Stop Daemon

**`[Debian:oppo$]`**
```bash
pm2 stop docs-portal
```

### Restart Daemon

**`[Debian:oppo$]`**
```bash
pm2 restart docs-portal
```

### View Live Access & Error Logs (RAM Buffer)

**`[Debian:oppo$]`**
```bash
tail -n 50 -f /dev/shm/docs-portal.log
```

---

## 2. CONFIGURATION & PATHS

| Component | Absolute Path (Inside Chroot) | Description |
| :--- | :--- | :--- |
| **Webroot Directory** | `/var/www/oppo-docs/` | Static files, Markdown runbooks, and SPA entrypoint |
| **SPA Entrypoint** | `/var/www/oppo-docs/index.html` | Docsify v4 core configuration and plugin loader |
| **Sidebar Hierarchy** | `/var/www/oppo-docs/_sidebar.md` | Navigation tree structure |
| **Volatile Access Logs**| `/dev/shm/docs-portal.log` | HTTP request traffic buffered in RAM tmpfs |
| **Volatile Error Logs** | `/dev/shm/docs-portal.err` | Python server stack traces in RAM tmpfs |
| **PM2 Process Config** | `container/pm2/ecosystem.config.js` | Tracked version-controlled startup definition |

---

## 3. OPERATOR DEPLOYMENT WORKFLOW

Docsify is a 100% client-side SPA. There is **no build step**, **no compiler**, and **no server restart** needed when updating documentation.

### From Workstation Terminal:
```powershell
powershell -ExecutionPolicy Bypass -File ./workstation/sync_docs.ps1
```
*(Or in VS Code: press `Ctrl+Shift+B` and select `Phone: Sync Docs to Phone`)*

Once SCP finishes transferring files, refresh `http://192.168.1.35:8080` in your browser. The updates render instantly.

---

## 4. TRIAGE & FAILURE MODES

| Symptom | Probable Root Cause | Resolution Protocol |
| :--- | :--- | :--- |
| **`Connection refused` on `:8080`** | `docs-portal` crashed or process supervisor died. | 1. Check process table: `/data/local/bin/chroot-debian.sh "su - oppo -c 'pm2 status'"`.<br>2. Inspect RAM errors: `cat /dev/shm/docs-portal.err`.<br>3. Restart process. |
| **Blank white screen in browser** | A file linked in `_sidebar.md` is 0 bytes or missing. | Ensure all `.md` files have at least a minimal title or status stub. Verify browser console (`F12`) for 404 paths. |
| **Sidebar navigation missing** | `_sidebar.md` is missing or `loadSidebar: true` disabled. | Verify `_sidebar.md` exists in `/var/www/oppo-docs/`. Check `index.html` configuration. |
| **`SCP: Permission denied` during sync** | `/var/www/oppo-docs` ownership reverted to root. | Reset userland ownership: `/data/local/bin/chroot-debian.sh "chown -R oppo:oppo /var/www/oppo-docs"`. |

---

## 5. PURGE & CLEANUP

To unregister the service and delete web files:

**`[Debian:oppo$]`**
```bash
# 1. Stop and remove from PM2
pm2 delete docs-portal && pm2 save

# 2. Wipe webroot and RAM buffers
rm -rf /var/www/oppo-docs
rm -f /dev/shm/docs-portal.log /dev/shm/docs-portal.err
```