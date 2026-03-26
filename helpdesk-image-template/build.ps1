# build.ps1 — Build the Helpdesk Docker image (Windows PowerShell)
#
# Usage:
#   .\build.ps1
#
# This script:
#   1. Reads apps.json and encodes it to Base64
#   2. Builds the Docker image using the official frappe/layered Containerfile
#   3. Tags the image as helpdesk:v16

$ErrorActionPreference = "Stop"

Write-Host "==> Encoding apps.json to Base64..." -ForegroundColor Cyan
$AppsJsonBase64 = [Convert]::ToBase64String(
    [System.IO.File]::ReadAllBytes(
        (Join-Path $PSScriptRoot "apps.json")
    )
)

Write-Host "==> Building helpdesk:v16 image..." -ForegroundColor Cyan
Write-Host "    This will take ~10-20 minutes on the first build." -ForegroundColor Yellow

docker build `
    --build-arg=FRAPPE_PATH=https://github.com/frappe/frappe `
    --build-arg=FRAPPE_BRANCH=version-16 `
    --build-arg=APPS_JSON_BASE64=$AppsJsonBase64 `
    --tag=helpdesk:v16 `
    --file="$PSScriptRoot\..\images\layered\Containerfile" `
    "$PSScriptRoot\.."

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "==> Build successful! Image: helpdesk:v16" -ForegroundColor Green
    Write-Host "    Next: cd into this folder and run:" -ForegroundColor White
    Write-Host "    docker compose -p helpdesk -f compose.helpdesk.yaml up -d" -ForegroundColor White
} else {
    Write-Host "==> Build FAILED. Check the output above." -ForegroundColor Red
    exit 1
}
