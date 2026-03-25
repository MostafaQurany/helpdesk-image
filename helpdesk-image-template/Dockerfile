# We define the version once at the top for easy updates
ARG FRAPPE_BRANCH=version-16
FROM frappe/base:${FRAPPE_BRANCH} AS builder

ARG FRAPPE_PATH=https://github.com/frappe/frappe
ARG FRAPPE_BRANCH=version-16

USER root
# Install build-time dependencies only. These won't be in the final image.
RUN apt-get update && apt-get install -y \
    git \
    jq \
    pkg-config \
    build-essential \
    libmariadb-dev \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

USER frappe
WORKDIR /home/frappe

# Copy the app list. This is where you add/remove apps.
COPY --chown=frappe:frappe apps.json /home/frappe/apps.json

# Step 1: Initialize the bench. We skip assets to speed up the build.
RUN bench init \
    --frappe-branch=${FRAPPE_BRANCH} \
    --frappe-path=${FRAPPE_PATH} \
    --apps_path=/home/frappe/apps.json \
    --no-procfile \
    --no-backups \
    --skip-redis-config-generation \
    --skip-assets \
    /home/frappe/frappe-bench

# Step 2: Pre-compile JS/CSS. This makes the container start instantly in production. [cite: 2]
RUN cd /home/frappe/frappe-bench && \
    bench build --app helpdesk

# Step 3: Clean up. We delete .git folders to reduce image size by ~40%. [cite: 3]
RUN find /home/frappe/frappe-bench/apps -mindepth 1 -path "*/.git" | xargs rm -rf

# Final Stage: The slim production image. [cite: 2, 3]
FROM frappe/base:${FRAPPE_BRANCH}

USER frappe
# Copy ONLY the bench folder from the builder. [cite: 2, 3]
COPY --from=builder --chown=frappe:frappe /home/frappe/frappe-bench /home/frappe/frappe-bench
WORKDIR /home/frappe/frappe-bench

# Persistent data locations [cite: 1]
VOLUME [ \
    "/home/frappe/frappe-bench/sites", \
    "/home/frappe/frappe-bench/sites/assets", \
    "/home/frappe/frappe-bench/logs" \
    ]

CMD ["/bin/bash"]
