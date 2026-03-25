# 🛠 Frappe Helpdesk: Custom Build & Deploy Template

This project contains the configuration files required to build a reusable, production-ready custom Docker image for Frappe Helpdesk using the official `frappe_docker` workflow.

It uses a multi-stage build to improve performance, reduce image size, and keep deployment efficient.

---

## 📂 Why these files matter

### 1. `apps.json` — App dependencies
Frappe Helpdesk is not a standalone app; it depends on other apps in the Frappe ecosystem.

- **ERPNext (`version-16`)**: Required for core customer and contact logic.
- **Payments (`develop`)**: Required for payment gateway features used by modern Frappe apps.
- **Telephony (`develop`)**: Optional for call support. If you only need email-based support, you can remove it.
- **Helpdesk (`develop`)**: The main application for ticket and support management.

### 2. `Dockerfile` — Build optimization
The image is built with production readiness in mind.

- **Precompiled assets**: `bench build` runs during image creation so CSS and JavaScript assets are already prepared.
- **Reduced image size**: `.git` folders are removed to keep the final image smaller and faster to transfer.

### 3. `compose.yaml` — Service orchestration
This file connects the application to its required infrastructure services.

- **Health checks**: Application services wait for the database to become ready before starting.
- **Service separation**: Dedicated Redis services for cache, queue, and Socket.IO help improve reliability and responsiveness.

---

## 🚀 Step-by-step launch guide

### Step 1: Build the environment
Build the custom image from scratch:

```bash
docker compose build --no-cache
```

### Step 2: Start backing services
Start the database and Redis services first:

```bash
docker compose up -d db redis-cache redis-queue redis-socketio
```

### Step 3: Create the site
Create the site database and install the Helpdesk app:

> **Important:** Use `--db-host db` so the container can reach the database service.

```bash
docker compose run --rm helpdesk-image \
  bench new-site site1.localhost \
  --mariadb-root-password root \
  --admin-password admin \
  --db-host db \
  --install-app helpdesk
```

### Step 4: Configure the Windows hosts file
Because the site is named `site1.localhost`, Windows must resolve that hostname to your local machine.

1. Open Notepad as Administrator.
2. Open `C:\Windows\System32\drivers\etc\hosts`.
3. Add the following line at the bottom of the file:

```text
127.0.0.1 site1.localhost
```

4. Save the file and close Notepad.

### Step 5: Launch everything
Start all services:

```bash
docker compose up -d
```

Then access the site at `http://site1.localhost:8000`.

- **Default user:** `Administrator`
- **Default password:** `admin`

---

## 🔄 How to update or change apps

If you want to add a new app such as `builder` or `hrms`:

1. Add the app repository URL and branch to `apps.json`.
2. Rebuild the image:

```bash
docker compose build
```

3. Install the app on the site:

```bash
docker compose run --rm helpdesk-image bench --site site1.localhost install-app [app_name]
```
