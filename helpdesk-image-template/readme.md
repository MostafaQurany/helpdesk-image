# Frappe Helpdesk (v16) Custom Docker Deployment

A production-ready, reusable custom Docker configuration for deploying Frappe Helpdesk using the official multi-stage build workflow. Built with best practices and patches specific to Frappe Version 16 constraints.

## Requirements

- Docker Desktop / engine installed
- Docker Compose installed

---

## Step-by-Step Launch Guide

### Step 1: Build the Custom Docker Image
Build the image from scratch utilizing the provided `apps.json` and `Dockerfile`. The `--no-cache` parameter ensures that the latest commits from the specified app branches are pulled cleanly.

```bash
docker compose build --no-cache
```

### Step 2: Start Infrastructure Dependencies
Spin up the database and Redis instances so they're ready.

```bash
docker compose up -d db redis-cache redis-queue redis-socketio
```
Wait about 10 seconds for the MariaDB (`db`) service to be healthy. Note: A dedicated healthcheck is configured inside the `compose.yaml`.

### Step 3: Create a New Site
Launch a transient web container context to setup Frappe's database and install the required apps.
**CRITICAL**: In v16, you must pass `--db-host db` so it communicates properly over the Docker network rather than defaulting to `localhost`.

```bash
docker compose run --rm helpdesk-web bench new-site site1.localhost 
  --mariadb-root-password admin 
  --admin-password admin 
  --db-host db
```

Afterward, install the Helpdesk application to the specific site:

```bash
docker compose run --rm helpdesk-web bench --site site1.localhost install-app helpdesk
```

Finally, set this site as the **default** so you never get a 404 error when navigating to `localhost`:

```bash
docker compose run --rm helpdesk-web bench use site1.localhost
```

### Step 4: Configure Local DNS (Hosts File)
Because the configuration depends on subdomain/domain resolution, map `site1.localhost` locally.

- **Windows:** Edit `C:\Windows\System32\drivers\etc\hosts` (Remember to open Notepad as Administrator).
- **macOS/Linux:** Edit `/etc/hosts`.

Append the following line at the very bottom:
```text
127.0.0.1 site1.localhost
```

### Step 5: Start All Services
Now it's time to launch the entire stack:
```bash
docker compose up -d
```

Sit back! Your site is deployed online. The web server listens on port `8000`.
Visit your browser and navigate to: **[http://site1.localhost:8000](http://site1.localhost:8000)**

---

## Key Refinements for Frappe v16 Compatibility

This configuration prevents known failures inherent to out-of-the-box deployments on standard v16 builds:

1. **App Branches Updated:** `payments`, `telephony`, and `helpdesk` branches correspond perfectly to `develop` to prevent missing `version-16` branch pull errors.
2. **Redis Config Omission Error (127):** Mitigated via the explicit incorporation of `--skip-redis-config-generation` in the `Dockerfile` during the staging phase.
3. **Web Server Host Error:** Mitigated via stripping out the defunct `--host 0.0.0.0` argument inside `compose.yaml`. Instead, routing focuses explicitly on `--port 8000`.
4. **Worker/Web Connection Exhaustion (111):** Passed proper Docker-network Redis URIs mapping natively into worker/web services inside `compose.yaml` (e.g., `REDIS_CACHE=redis://redis-cache:6379`).
5. **Database Connector (2002):** Mitigated by the mandatory inclusion of `--db-host db` applied during the `bench new-site` initialization phase.
