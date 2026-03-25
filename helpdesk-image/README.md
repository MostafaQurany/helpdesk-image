# Frappe Helpdesk custom image

This directory packages Frappe Helpdesk into a reusable custom bench image using the upstream custom-image workflow from [`frappe_docker`](../README.md). The recommended approach is the same pattern shown in [`helpdesk-image-template/Dockerfile`](../helpdesk-image-template/Dockerfile): bake the app into the image at build time with [`bench init --apps_path`](../helpdesk-image-template/Dockerfile:26), then reuse that image for the normal bench-based services in deployment.

## Why this approach

This implementation chooses the upstream custom-image pattern instead of runtime `bench get-app` installation because it is:

- immutable and repeatable
- easier to pin and version
- compatible with Frappe/ERPNext-style bench containers
- simpler to promote through environments

## Files

- [`apps.json`](apps.json) defines which custom apps are baked into the image
- [`Dockerfile`](Dockerfile) builds a bench with Helpdesk already present
- [`.dockerignore`](.dockerignore) keeps the build context small
- [`compose.build.yaml`](compose.build.yaml) gives a repeatable build entrypoint

## Pinning strategy

The default implementation is pinned to Frappe v15 through [`ARG FRAPPE_BRANCH=version-15`](Dockerfile:2). For production, keep two things pinned:

1. the framework/image line via [`FRAPPE_BRANCH`](Dockerfile:2)
2. the Helpdesk source ref via [`apps.json`](apps.json)

The sample [`apps.json`](apps.json) uses the current upstream release tag `v1.21.3`, because the Helpdesk repository does not expose a `version-15` branch. If you require stricter reproducibility, replace that tag with an exact commit SHA.

Example:

```json
[
  {
    "url": "https://github.com/frappe/helpdesk",
    "branch": "v1.2.3"
  }
]
```

## Build the image

From the repository root:

```bash
docker build \
  --file helpdesk-image/Dockerfile \
  --tag ghcr.io/example/frappe-helpdesk:15.0.0-helpdesk.1 \
  helpdesk-image
```

Or use [`compose.build.yaml`](compose.build.yaml):

```bash
docker compose -f helpdesk-image/compose.build.yaml build
```

You can override the image name and build variables through environment values:

```bash
HELPDESK_IMAGE=ghcr.io/example/frappe-helpdesk:15.0.0-helpdesk.1 \
FRAPPE_BRANCH=version-15 \
docker compose -f helpdesk-image/compose.build.yaml build
```

## Tagging and versioning

Use explicit tags that reflect both the framework line and your image revision.

Recommended examples:

- `ghcr.io/example/frappe-helpdesk:15.0.0-helpdesk.1`
- `ghcr.io/example/frappe-helpdesk:15.0.0-helpdesk.2`
- `ghcr.io/example/frappe-helpdesk:version-15-20260325`

Versioning rule:

- bump the image tag whenever [`apps.json`](apps.json) changes
- bump the image tag whenever the Frappe base line or Dockerfile logic changes

## Verify that Helpdesk is included

### Verify the app exists in the bench

```bash
docker run --rm ghcr.io/example/frappe-helpdesk:15.0.0-helpdesk.1 \
  bash -lc "ls -1 apps && test -d apps/helpdesk"
```

### Verify through [`bench version`](Dockerfile:22)

```bash
docker run --rm ghcr.io/example/frappe-helpdesk:15.0.0-helpdesk.1 \
  bash -lc "bench version"
```

Expected result:

- the image contains `apps/helpdesk`
- [`bench version`](Dockerfile:22) reports the bench and app sources available in the image

## Install the app on a site

Baking Helpdesk into the image makes it available in the bench. A site still needs the app installed in its database.

Typical one-time provisioning step:

```bash
bench --site <site-name> install-app helpdesk
```

Then verify:

```bash
bench --site <site-name> list-apps
```

Expected result: `helpdesk` appears in the site app list.

## Use the image in a typical deployment

Use the same custom image wherever a standard Frappe bench image would normally be used: backend, workers, scheduler, websocket, and one-shot jobs.

Example deployment override:

```yaml
services:
  backend:
    image: ghcr.io/example/frappe-helpdesk:15.0.0-helpdesk.1

  queue-short:
    image: ghcr.io/example/frappe-helpdesk:15.0.0-helpdesk.1

  queue-long:
    image: ghcr.io/example/frappe-helpdesk:15.0.0-helpdesk.1

  scheduler:
    image: ghcr.io/example/frappe-helpdesk:15.0.0-helpdesk.1

  websocket:
    image: ghcr.io/example/frappe-helpdesk:15.0.0-helpdesk.1
```

This keeps all bench workloads on the same application tree and avoids drift between services.

## App installation strategy

Recommended split of responsibilities:

- image build: include Helpdesk source code using [`apps.json`](apps.json)
- site provisioning: run `bench --site <site-name> install-app helpdesk`
- ongoing deployment: reuse the same immutable image across bench services

Avoid cloning the app at runtime in production containers.

## Publishing

After a successful build and verification:

```bash
docker push ghcr.io/example/frappe-helpdesk:15.0.0-helpdesk.1
```

Promote that exact tag into staging and production rather than rebuilding per environment.
