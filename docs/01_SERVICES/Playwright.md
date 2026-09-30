# Playwright & Browser Automation (Sub-Tab: 01_SERVICES)

> **Architectural Status:** **STRICTLY PROHIBITED (ANTI-PATTERN)**  
> **Classification:** Incompatible Platform Workload  
> **Blast Radius:** **CRITICAL**. Attempting to deploy full headless browser runtimes causes container kernel panics, CPU thermal throttling, and complete memory starvation.

---

## 1. THE ARCHITECTURAL BAN

Headless browser runtimes (**Chromium**, **Puppeteer**, **Playwright**, **Selenium**) and Android GUI automation tools (**uiautomator**, **Appium**) are **permanently barred** from execution inside this machine.

| Prohibited Workload | Primary Failure Mechanism | Impact on Oppo A91 Host |
| :--- | :--- | :--- |
| **Playwright / Chromium** | Kernel `CLONE_NEWUSER` unprivileged user namespace sandbox failure. | Chrome crashes on startup with `Failed to launch browser: No usable sandbox`. Disabling the sandbox (`--no-sandbox`) creates severe root escape vulnerabilities. |
| **Browser Multiprocessing** | Heavy multi-process tab allocation churning 800 MB–1.5 GB per page. | Cortex-A73 cluster reaches 85°C thermal limits within 90 seconds, inducing MTK hardware throttling. |
| **Android UIAutomator** | Requires active Android display compositors (`SurfaceFlinger`) and `Zygote`. | Invalidates the headless `stop` memory reclaim, forcing the host to allocate ~3.5 GB of RAM back to Android GUI processes. |

---

## 2. THE APPROVED ALTERNATIVE ARCHITECTURE

For workloads requiring web ingestion, data harvesting, or automated interaction (e.g., the AliExpress purchase evaluator):

```text
[Operator Workstation (PC / Laptop)]
├── Headful Chrome / Firefox / Tampermonkey
├── Executes DOM evaluation & JS rendering on workstation CPU
└── Emits structured, pre-parsed JSON payload
         │
         ▼  (HTTP POST over Tailnet / LAN)
[Oppo A91 Headless Server (:20128 / :20129)]
├── Ingests lightweight JSON via Fastify / Express
├── Appends payload to SQLite on UFS flash
└── Zero browser rendering overhead on ARM silicon
```

1. **Workstation-Side Execution:**  
   Run complex JavaScript rendering, Cloudflare/turnstile solving, and DOM parsing on your desktop PC using Tampermonkey user-scripts, client-side extensions, or local Node scripts.
2. **Headless Payload Ingestion:**  
   The workstation script posts clean, structured JSON payloads directly to an API endpoint running on the phone.
3. **Total Server Efficiency:**  
   The server processes thousands of incoming data points using <25 MB of RAM and ~0% CPU, completely bypassing browser sandboxing traps.