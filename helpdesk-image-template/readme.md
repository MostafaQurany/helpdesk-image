# Frappe Helpdesk — Docker Compose Deployment

A **self-contained**, production-ready Docker Compose deployment for [Frappe Helpdesk](https://github.com/frappe/helpdesk) v1.21+ on Frappe v16.

---

## What Is This?

This folder contains everything needed to build, deploy, and run Frappe Helpdesk as a set of Docker containers. It uses the **official `frappe_docker` workflow** — no custom Dockerfiles, no manual dependency management.

### Architecture

The deployment runs **10 containers** working together:

```
┌─────────────────────────────────────────────────────┐
│                   Your Browser                      │
│              http://site1.localhost:8080             │
└─────────────────┬───────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────┐
│  frontend (Nginx)          — reverse proxy, :8080   │
│  ├── backend (Gunicorn)    — Python/Frappe API      │
│  └── websocket (Socket.IO) — real-time updates      │
└─────────────────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────┐
│  configurator — one-shot setup (runs once, exits)   │
│  scheduler    — cron-like background jobs           │
│  queue-short  — fast background tasks               │
│  queue-long   — heavy background tasks              │
└─────────────────────────────────────────────────────┘
                  │
┌─────────────────▼───────────────────────────────────┐
│  db (MariaDB 11.8)    — primary database            │
│  redis-cache           — in-memory cache            │
│  redis-queue           — job queue broker            │
└─────────────────────────────────────────────────────┘
```

| Service | Image | Purpose |
|---|---|---|
| `frontend` | `helpdesk:v16` | Nginx reverse proxy, serves static assets, port 8080 |
| `backend` | `helpdesk:v16` | Gunicorn WSGI server running Frappe/Helpdesk Python code |
| `websocket` | `helpdesk:v16` | Socket.IO server for real-time browser updates |
| `configurator` | `helpdesk:v16` | One-shot init: writes `site_config.json` with DB/Redis hosts, then exits |
| `scheduler` | `helpdesk:v16` | Runs `bench schedule` — cron-like periodic tasks |
| `queue-short` | `helpdesk:v16` | Processes short/default background jobs (email, notifications) |
| `queue-long` | `helpdesk:v16` | Processes long-running jobs (imports, reports) |
| `db` | `mariadb:11.8` | MariaDB database server |
| `redis-cache` | `redis:6.2-alpine` | In-memory cache for frequently accessed data |
| `redis-queue` | `redis:6.2-alpine` | Message broker for the background job queue |

---

## Why This Approach?

We use the **official `frappe_docker` layered Containerfile** instead of writing a custom Dockerfile. Here's why:

| Problem | Custom Dockerfile | Official Layered Build |
|---|---|---|
| Missing `pkg-config` | ❌ Build fails — must manually install | ✅ Pre-installed in `frappe/build` image |
| Python version issues | ❌ Must pin & manage Python | ✅ Upstream handles Python 3.14 |
| Nginx configuration | ⚠️ Hand-maintained `nginx.conf` | ✅ Built into `frappe/base` image |
| Gunicorn CMD | ⚠️ Must hardcode path | ✅ Pre-configured in Containerfile |
| Redis/DB configuration | ⚠️ Manual env vars | ✅ `configurator` service does it |
| Upstream updates | ⚠️ Must manually merge fixes | ✅ Just `git pull` + rebuild |
| Build reproducibility | ⚠️ Depends on network at build time | ✅ Multi-stage, cached layers |

### How the build works

```
apps.json ──▶ base64 encode ──▶ APPS_JSON_BASE64 build arg
                                       │
                                       ▼
              images/layered/Containerfile
              ┌──────────────────────────────┐
              │ Stage 1: frappe/build        │
              │   • Clone frappe (v16)       │
              │   • Clone apps from JSON     │
              │   • pip install all apps     │
              │   • yarn install + build     │
              ├──────────────────────────────┤
              │ Stage 2: frappe/base         │
              │   • COPY from Stage 1        │
              │   • Lean runtime image       │
              └──────────────┬───────────────┘
                             │
                             ▼
                      helpdesk:v16 image
```

The `frappe/build` image is a fat builder with `gcc`, `pkg-config`, `node`, `yarn`, etc. The `frappe/base` image is a slim runtime with just Python + system libs. The multi-stage build keeps the final image small (~1.5 GB vs ~3+ GB if everything was in one stage).

---

## File Descriptions

| File | Purpose |
|---|---|
| `apps.json` | Defines which Frappe apps to bake into the image (Telephony + Helpdesk) |
| `.env` | Environment variables: image name/tag, DB password, site name |
| `compose.helpdesk.yaml` | **Fully flattened** Docker Compose file — all 10 services, no external dependencies |
| `build.ps1` | Windows PowerShell build script |
| `build.sh` | Linux/WSL/macOS build script |
| `README.md` | This file |

### `apps.json` — Why these apps?

```json
[
  { "url": "https://github.com/frappe/telephony", "branch": "develop" },
  { "url": "https://github.com/frappe/helpdesk",  "branch": "main"    }
]
```

- **Telephony** (`develop`) — Required dependency of Helpdesk. Has no `version-16` branch, so we use `develop`.
- **Helpdesk** (`main`) — The main app. Has no `version-16` branch either, `main` is the stable release.
- **Frappe** — Not listed because it's the framework itself (installed automatically via `FRAPPE_BRANCH=version-16`).

### `compose.helpdesk.yaml` — Why is it so large?

This file was **generated** (not hand-written) by merging 4 upstream files:

```
compose.yaml                    ← core services (backend, frontend, workers)
+ overrides/compose.mariadb.yaml  ← adds MariaDB service
+ overrides/compose.redis.yaml    ← adds Redis services
+ overrides/compose.noproxy.yaml  ← exposes port 8080 directly (no Traefik)
= compose.helpdesk.yaml           ← fully self-contained result
```

The merge was done with `docker compose config`, which resolves all variables, anchors, and overrides into a single flat file. This means **you never need the parent repo's override files** — everything is baked in.

### `.env` — What each variable does

```env
ERPNEXT_VERSION=v16          # Frappe framework version (used in compose template)
DB_PASSWORD=admin            # MariaDB root password
CUSTOM_IMAGE=helpdesk        # Docker image name
CUSTOM_TAG=v16               # Docker image tag
PULL_POLICY=missing          # Don't pull from Docker Hub — use local image
FRAPPE_SITE_NAME_HEADER=site1.localhost  # Nginx routes requests to this site
```

---

## Prerequisites

- **Docker Desktop** (Windows/macOS) or **Docker Engine** (Linux)
- **Docker Compose v2** (included with Docker Desktop)
- The parent `frappe_docker` repo (for `images/layered/Containerfile` during build only)

---

## Quick Start

### 1. Build the Image

**Windows (PowerShell):**
```powershell
.\build.ps1
```

**Linux / WSL / macOS:**
```bash
chmod +x build.sh
./build.sh
```

> ⏱️ First build takes ~10-20 minutes. Subsequent builds are cached and much faster.

### 2. Start All Services

```bash
docker compose -p helpdesk -f compose.helpdesk.yaml up -d
```

Wait ~15 seconds for MariaDB to become healthy and the configurator to finish.

### 3. Create Site & Install Helpdesk

```bash
docker compose -p helpdesk exec backend \
  bench new-site site1.localhost \
  --mariadb-user-host-login-scope='%' \
  --db-root-password admin \
  --admin-password admin \
  --install-app helpdesk
```

When prompted for mysql super user, press Enter to accept the default (`root`).

### 4. Set as Default Site

```bash
docker compose -p helpdesk exec backend bench use site1.localhost
```

### 5. Enable Scheduler

```bash
docker compose -p helpdesk exec backend bench --site site1.localhost enable-scheduler
```

### 6. Add Hosts Entry

Add this line to `C:\Windows\System32\drivers\etc\hosts` (as Administrator):
```
127.0.0.1 site1.localhost
```

### 7. Access

Open **http://site1.localhost:8080**

- **Username:** `Administrator`
- **Password:** `admin`

---

## Common Operations

### Stop services
```bash
docker compose -p helpdesk -f compose.helpdesk.yaml stop
```

### Start services (after stop)
```bash
docker compose -p helpdesk -f compose.helpdesk.yaml start
```

### View logs
```bash
docker compose -p helpdesk -f compose.helpdesk.yaml logs -f backend
```

### Remove everything (including data)
```bash
docker compose -p helpdesk -f compose.helpdesk.yaml down -v
```

### Rebuild after changing `apps.json`
```powershell
.\build.ps1  # rebuilds the image
docker compose -p helpdesk -f compose.helpdesk.yaml up -d  # restarts with new image
docker compose -p helpdesk exec backend bench --site site1.localhost migrate  # applies DB changes
```

---

## Troubleshooting

| Problem | Solution |
|---|---|
| `TLS handshake timeout` during build | Retry — transient Docker Hub network issue |
| `No module named 'telephony'` | Telephony is missing from `apps.json` — add it and rebuild |
| Site not loading / 502 error | Wait 15s for configurator to finish: `docker compose -p helpdesk logs configurator` |
| `ERR_NAME_NOT_RESOLVED` | Add `127.0.0.1 site1.localhost` to your hosts file |
| Port 8080 already in use | Change the `published: "8080"` line in `compose.helpdesk.yaml` |
| MariaDB won't start | Check if port 3306 is used: `docker compose -p helpdesk logs db` |
