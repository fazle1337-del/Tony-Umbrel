# Pen Test Tracker — Umbrel app store entry

This repo is the Umbrel community app store entry for Pen Test Tracker
(store: "tony", app ID: `tony-pen-test-tracker`).

## Hard constraint — do not violate

The `tony-pen-test-tracker/` folder contains **only**:

- `docker-compose.yml`
- `umbrel-app.yml`

**Never add anything else here** — no source code, no Dockerfiles, no scripts,
no `deploy.sh`, no docs. Application source lives in the **separate main project
repo**, and main-project files leaking into this folder has been a recurring
problem. If a task seems to need another file in this folder, stop and confirm
first.

## What does belong here

- Editing `docker-compose.yml` — the image references (`tonybooom/...`), ports,
  and environment wiring Umbrel uses to run the app.
- Editing `umbrel-app.yml` — the store manifest (name, version, description, etc.).

## Umbrel secrets (compose file only)

Umbrel community apps don't handle `.env`-style secrets reliably. In
`docker-compose.yml`:

- `${APP_SEED}` — JWT secret and Postgres password
- `${APP_PASSWORD}` — seed admin password
- All other environment variables are hardcoded directly in the compose file
