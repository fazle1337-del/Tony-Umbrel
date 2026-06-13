# Pen Test Tracker — Umbrel app

App folder for your existing **`tony`** Umbrel Community App Store. Drop the
`tony-pen-test-tracker/` folder into the same repo as your other apps
(`tony-macro-tracker-pwa`, etc.) — your store's `umbrel-app-store.yml`
(`id: tony`) already covers it, so no store manifest is included here.

## Files

```
tony-pen-test-tracker/
  umbrel-app.yml         # listing shown in umbrelOS
  docker-compose.yml     # api + postgres, behind Umbrel's app_proxy
```

## One required step: publish the backend image

Umbrel installs from pre-built images, not source. Build and push the backend
image to your Gitea registry first. The workflow in the main Pen Test Tracker
repo (`.gitea/workflows/build-backend.yml`) does this on a tag push:

```bash
git tag v0.1.0
git push origin v0.1.0
```

It builds multi-arch (arm64 for the Pi5, amd64 for Azure). Then set the matching
reference in `tony-pen-test-tracker/docker-compose.yml`, ideally by digest:

```yaml
image: git.yourhost.com/tony/pen-test-tracker-backend:0.1.0@sha256:<digest>
```

If your registry needs auth to pull, run `docker login git.yourhost.com` on the
Pi5 once.

## Placeholders to edit

- `git.example.com/tony/...` in the compose file → your Gitea host.
- `icon` in `umbrel-app.yml` is a generic Flaticon shield; swap for your own.
- Fill `website`/`repo`/`support`/`submission` if you want them populated.

## First launch

- Seeds one **InfoSec admin** on first boot.
- Username: `admin@example.com` (hardcoded in the compose file for now —
  Umbrel doesn't reliably pass custom env vars yet; change it there directly).
- Password: Umbrel's per-app password (`${APP_PASSWORD}`), on the app info
  screen. Change it after first login.
- `JWT_SECRET` and the Postgres password derive from `${APP_SEED}` — stable
  across restarts, nothing committed to the repo.

## Data persistence

- Postgres: `${APP_DATA_DIR}/data/postgres`
- Attachments: `${APP_DATA_DIR}/data/attachments`

Survives stop/start and updates; cleared on uninstall (Umbrel's model).

## Note

`path: /docs` opens the FastAPI interactive docs — the usable interface until
the React frontend lands. Update `port`/`path` then.
