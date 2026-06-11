# Macro Tracker

A self-hosted macro tracking app. Stack: Nginx + Node/Express + PostgreSQL, all in Docker.

## Quick Start

### 1. Clone / copy files to your Pi

```bash
scp -r macro-tracker/ umbrel@YOUR_PI_IP:~/macro-tracker
ssh umbrel@YOUR_PI_IP
cd ~/macro-tracker
```

### 2. Create your .env file

```bash
cp .env.example .env
nano .env
```

Fill in:
```
DB_PASSWORD=pick_a_strong_password
API_SECRET=run_openssl_rand_hex_32_to_generate
```

Generate a secret:
```bash
openssl rand -hex 32
```

### 3. Set your API key in the frontend

Open `frontend/index.html` and find this line near the bottom:

```js
const API_KEY = window.API_KEY || 'REPLACE_WITH_YOUR_API_SECRET';
```

Replace `REPLACE_WITH_YOUR_API_SECRET` with the same value you put in `API_SECRET` in `.env`.

### 4. Build and start

```bash
docker compose up -d --build
```

App is now at: `http://YOUR_PI_IP:8080`

---

## Accessing from other devices

On your local network: `http://YOUR_PI_IP:8080`

Find your Pi's IP:
```bash
hostname -I
```

To access from outside your home network, set up Tailscale (recommended for Umbrel):
- Tailscale is available in the Umbrel App Store
- Once installed, use your Tailscale IP: `http://YOUR_TAILSCALE_IP:8080`

---

## Useful commands

```bash
# View logs
docker compose logs -f

# Stop
docker compose down

# Restart
docker compose restart

# Update after code changes
docker compose up -d --build

# Backup database
docker exec macro-tracker-db pg_dump -U macrouser macrotracker > backup_$(date +%F).sql

# Restore database
cat backup_YYYY-MM-DD.sql | docker exec -i macro-tracker-db psql -U macrouser macrotracker
```

---

## Adding multi-user support (future)

The API is structured to make this easy:
1. Add a `users` table with `id`, `username`, `password_hash`
2. Replace the `x-api-key` middleware with JWT auth (`jsonwebtoken` package)
3. Add `user_id` foreign key to `log_entries` and `foods`
4. Add `/auth/login` and `/auth/register` endpoints
5. Frontend: add a login screen that stores the JWT in localStorage

---

## Project structure

```
macro-tracker/
├── docker-compose.yml
├── .env.example
├── .gitignore
├── README.md
├── backend/
│   ├── Dockerfile
│   ├── package.json
│   └── server.js        ← Express API + DB schema + seed data
└── frontend/
    ├── Dockerfile
    ├── nginx.conf        ← Proxies /api/* to backend (no CORS issues)
    └── index.html        ← Full app, talks to /api/*
```
