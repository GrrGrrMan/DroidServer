# Base System Packages (`00_base`)

> **Role:** Core interactive CLI utilities and system inspectors.  
> **Lifecycle:** Debian APT package suite managed via declarative manifest (`packages.apt`).  
> **Flash Wear:** Cached archives purged immediately via `apt-get clean`.

---

## 1. INSTALLED UTILITIES

| Utility | Command | Purpose |
| :--- | :--- | :--- |
| **htop** | `htop` | Interactive process viewer and per-core CPU telemetry (A73 vs A53 clusters). |
| **tmux** | `tmux` | Terminal multiplexer for persistent interactive sessions. |
| **curl** | `curl` | HTTP/HTTPS transfer client for API interaction. |
| **jq** | `jq` | Lightweight command-line JSON processor. |
| **ncdu** | `ncdu` | NCurses disk usage analyzer for storage monitoring. |

---

## 2. EXTENSION CONTRACT

To add any standard Debian package to this server:
1. Append the package name to `workloads/00_base/packages.apt`.
2. Run `Phone: Deploy Workloads` from VS Code (`Ctrl+Shift+B`).