# Stage 1: Builder
FROM frappe/base:version-16 AS builder

# Change to root user to install build dependencies
USER root
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    make \
    python3-dev \
    libffi-dev \
    libssl-dev \
    pkg-config \
    libmariadb-dev \
    cron \
 && rm -rf /var/lib/apt/lists/*

# Switch back to frappe user for bench commands
USER frappe

# Init bench, skipping redis config generation and assets compilation initially
RUN bench init \
    --skip-assets \
    --skip-redis-config-generation \
    --frappe-path https://github.com/frappe/frappe \
    --frappe-branch version-16 \
    /home/frappe/frappe-bench

WORKDIR /home/frappe/frappe-bench

# Copy apps list to image
COPY apps.json /opt/frappe/apps.json

# Parse apps.json and run bench get-app for each app, omitting resolve-deps
RUN python3 -c "import json, subprocess; \
apps = json.load(open('/opt/frappe/apps.json')); \
[subprocess.run(['bench', 'get-app', app['url'], '--branch', app['branch']], check=True) for app in apps]"

# Build assets for all installed apps
RUN bench build

# Strip .git folders to significantly reduce final image size
RUN find /home/frappe/frappe-bench/apps -type d -name ".git" -exec rm -rf {} +

# Stage 2: Final Image
FROM frappe/base:version-16

USER frappe

# Copy built frappe-bench directory from the builder stage
COPY --from=builder /home/frappe/frappe-bench /home/frappe/frappe-bench

WORKDIR /home/frappe/frappe-bench

# Pre-create logs directory to guarantee proper ownership by frappe user before volume mounting
RUN mkdir -p /home/frappe/logs

# Declare external volumes for persistent data (sites, assets, and logs)
VOLUME [ "/home/frappe/frappe-bench/sites", "/home/frappe/frappe-bench/logs", "/home/frappe/frappe-bench/sites/assets" ]
