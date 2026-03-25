ARG FRAPPE_PATH=https://github.com/frappe/frappe
ARG FRAPPE_BRANCH=version-15

FROM frappe/base:${FRAPPE_BRANCH} AS builder

ARG FRAPPE_PATH
ARG FRAPPE_BRANCH

USER root

RUN apt-get update && apt-get install -y \
    git \
    jq \
    pkg-config \
    build-essential \
    libmariadb-dev \
    libmariadb-dev-compat \
    && rm -rf /var/lib/apt/lists/*

USER frappe
WORKDIR /home/frappe

COPY --chown=frappe:frappe apps.json /home/frappe/apps.json

RUN bench init \
    --frappe-branch=${FRAPPE_BRANCH} \
    --frappe-path=${FRAPPE_PATH} \
    --apps_path=/home/frappe/apps.json \
    --no-procfile \
    --no-backups \
    --skip-redis-config-generation \
    --verbose \
    /home/frappe/frappe-bench \
    && cd /home/frappe/frappe-bench \
    && echo "{}" > sites/common_site_config.json \
    && find apps -mindepth 1 -path "*/.git" | xargs rm -rf

FROM frappe/base:${FRAPPE_BRANCH}

ARG FRAPPE_BRANCH
LABEL org.opencontainers.image.title="frappe-helpdesk"
LABEL org.opencontainers.image.description="Custom Frappe bench image with Helpdesk baked in"
LABEL org.opencontainers.image.version="${FRAPPE_BRANCH}"

USER frappe
COPY --from=builder --chown=frappe:frappe /home/frappe/frappe-bench /home/frappe/frappe-bench
WORKDIR /home/frappe/frappe-bench

VOLUME ["/home/frappe/frappe-bench/sites", "/home/frappe/frappe-bench/sites/assets", "/home/frappe/frappe-bench/logs"]

CMD ["/bin/bash"]
