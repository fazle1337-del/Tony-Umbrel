# Pen Test Tracker — Umbrel app

App folder for the **`tony`** Umbrel Community App Store. Drop the
`tony-pen-test-tracker/` folder into the same repo as your other apps.

## Files

```
tony-pen-test-tracker/
  umbrel-app.yml         # listing shown in umbrelOS
  docker-compose.yml     # web (nginx+React) -> api (FastAPI) -> db (postgres)
```

## Architecture

```
app_proxy  ->  web (nginx :8080)  ->  /api/*  ->  api (FastAPI :8000)  ->  db (postgres)
                     |
                     serves the React bundle for all other paths
```

The web container serves the UI and reverse-proxies /api to the backend, so
only the frontend is exposed through Umbrel's app_proxy.

## Two images to publish

Umbrel installs pre-built images, not source. Build and push BOTH to Docker Hub
before installing. From the main project repo on a machine with Docker buildx:

```bash
docker login -u tonybooom

# backend
docker buildx build --platform linux/amd64,linux/arm64 \
  -t tonybooom/pen-test-tracker-backend:0.2.0 --push ./backend

# frontend
docker buildx build --platform linux/amd64,linux/arm64 \
  -t tonybooom/pen-test-tracker-frontend:0.2.0 --push ./frontend
```

(Or push a git tag — the .gitea/workflows build-backend.yml and
build-frontend.yml do both automatically.)

Then pin digests in docker-compose.yml (recommended):

```bash
docker buildx imagetools inspect tonybooom/pen-test-tracker-frontend:0.2.0
```

Use the top-level index digest: `...:0.2.0@sha256:<digest>`.

## First launch

- Seeds one InfoSec admin on first boot.
- Username: admin@example.com (hardcoded in compose; change there).
- Password: Umbrel's per-app password (${APP_PASSWORD}), on the app info screen.
  Change it after first login.
- JWT secret and Postgres password derive from ${APP_SEED}.

## Data persistence

- Postgres: ${APP_DATA_DIR}/data/postgres
- Attachments: ${APP_DATA_DIR}/data/attachments

## Notes

- The app now opens directly to the web UI (Findings / Tests / BAU Schedule /
  Scopes). The API remains reachable under /api and its docs at /api/docs.
- The login token is held in memory, so a hard refresh returns you to the
  sign-in screen. Persisting sessions is a planned enhancement.
