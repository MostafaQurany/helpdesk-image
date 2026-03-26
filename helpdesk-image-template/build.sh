#!/usr/bin/env bash
# build.sh — Build the Helpdesk Docker image (Linux / WSL / macOS)
#
# Usage:
#   chmod +x build.sh
#   ./build.sh
#
# This script:
#   1. Reads apps.json and encodes it to Base64
#   2. Builds the Docker image using the official frappe/layered Containerfile
#   3. Tags the image as helpdesk:v16

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Encoding apps.json to Base64..."
APPS_JSON_BASE64=$(base64 -w 0 "${SCRIPT_DIR}/apps.json")

echo "==> Building helpdesk:v16 image..."
echo "    This will take ~10-20 minutes on the first build."

docker build \
    --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe \
    --build-arg=FRAPPE_BRANCH=version-16 \
    --build-arg=APPS_JSON_BASE64="${APPS_JSON_BASE64}" \
    --tag=helpdesk:v16 \
    --file="${SCRIPT_DIR}/../images/layered/Containerfile" \
    "${SCRIPT_DIR}/.."

echo ""
echo "==> Build successful! Image: helpdesk:v16"
echo "    Next: cd into this folder and run:"
echo "    docker compose -p helpdesk -f compose.helpdesk.yaml up -d"
