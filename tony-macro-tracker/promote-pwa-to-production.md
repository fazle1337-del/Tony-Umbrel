# Task: Promote PWA-TEST frontend code to the Production "macro-tracker" app

## Objective
Make the **production** app (`tony-macro-tracker`, port 8069) serve the **same frontend
application code** as the **PWA-TEST** app (`tony-macro-tracker-pwa`, port 8070), while
keeping production's own infrastructure (its API container, its database, its network, its
port, its image tag) intact, and **without modifying or rebuilding anything the PWA-TEST
app uses.**

This is a frontend-only promotion. The two apps already share the **same API image**
(`tonybooom/macro-tracker-api:latest`), so no backend/API work is in scope.

---

## Assumption (confirm or override before running)
Production will gain **full PWA parity**: service worker + manifest + icons, i.e. it becomes
installable and offline-capable, exactly like PWA-TEST.

If instead you want production to stay a plain (non-PWA) web app and only inherit the
application logic, do the **Logic-only variant** in the Appendix instead of Steps 2–4.

---

## The two apps (do not blur them)

| | Production | PWA-TEST |
|---|---|---|
| App dir | `tony-macro-tracker/` | `tony-macro-tracker-pwa/` |
| Frontend image | `tonybooom/macro-tracker-frontend:latest` | `tonybooom/macro-tracker-frontend:feature-pwa` |
| Frontend container | `macro-tracker-frontend` | `macro-tracker-frontend-pwa` |
| API service (nginx proxy target) | `macro-tracker-api` | `macro-tracker-api-pwa` |
| Database container | `macro-tracker-db` | `macro-tracker-db-pwa` |
| Port | 8069 | 8070 |
| Network isolation | umbrel_main_network | umbrel_main_network + `pwa_internal` |

The API image `tonybooom/macro-tracker-api:latest` is **shared by both apps**.

---

## HARD GUARDRAILS — violating any of these breaks segregation. Do NOT:
1. **Do NOT** change production `nginx.conf`'s proxy target. It must remain
   `http://macro-tracker-api:3001`. Never `...-pwa`.
2. **Do NOT** rebuild, retag, or push `tonybooom/macro-tracker-api:latest` (shared — would hit both apps).
3. **Do NOT** rebuild, retag, or push `tonybooom/macro-tracker-frontend:feature-pwa` (that is the PWA image).
4. **Do NOT** edit any file under `tony-macro-tracker-pwa/`. Read-only source for this task.
5. **Do NOT** copy `docker-compose.yml` or `umbrel-app.yml` between the apps.
6. **Do NOT** copy `nginx.conf` from PWA-TEST into production. You will *edit* production's own
   nginx.conf (Step 3), keeping its proxy target.
7. **Do NOT** run `docker build` on an x86 machine. Builds MUST run on the Raspberry Pi (ARM64).
   Verify with `uname -m` → must be `aarch64`. If it is not, stop after Step 5 (commit/push) and
   run Steps 6–7 on the Pi.

---

## Paths
- Repo root on the Pi: `~/umbrel/app-stores/fazle1337-tony-umbrel-192-6304cbed`
- Gitea remote (source of truth): `http://192.168.1.118:8085/fazle1337/Tony-Umbrel.git`
- Production frontend dir: `<repo>/tony-macro-tracker/frontend`
- PWA-TEST frontend dir (read-only source): `<repo>/tony-macro-tracker-pwa/frontend`

Set a variable for convenience:
```bash
REPO=~/umbrel/app-stores/fazle1337-tony-umbrel-192-6304cbed
PROD=$REPO/tony-macro-tracker/frontend
PWA=$REPO/tony-macro-tracker-pwa/frontend
```

---

## STEP 0 — Pre-flight (record baseline so we can prove the PWA was untouched)
```bash
cd $REPO && git status            # working tree should be clean; pull latest from Gitea first if needed
uname -m                          # note the arch (must be aarch64 for the build steps)

# PWA-TEST baseline — these must be IDENTICAL again at the end
sudo docker exec macro-tracker-frontend-pwa grep -n CACHE_NAME /usr/share/nginx/html/sw.js
sudo docker exec macro-tracker-db-pwa psql -U macrouser -d macrotracker -c "SELECT count(*) FROM log_entries;"

# Safety net: snapshot the CURRENT production frontend image so we can roll back
# (the :latest tag will be overwritten by this task)
sudo docker tag tonybooom/macro-tracker-frontend:latest tonybooom/macro-tracker-frontend:pre-pwa-backup || true
```

---

## STEP 1 — Copy the application + asset files into production
Copy from PWA-TEST into production frontend. These five files are environment-agnostic and
are copied verbatim:
```bash
cp $PWA/index.html      $PROD/index.html
cp $PWA/sw.js           $PROD/sw.js
cp $PWA/manifest.json   $PROD/manifest.json
cp $PWA/1047711.png     $PROD/1047711.png
cp $PWA/2515263.png     $PROD/2515263.png
```

---

## STEP 2 — Set a fresh CACHE_NAME in production's sw.js
`CACHE_NAME` is the verification token for the whole deploy pipeline. Give production its own
distinct value so the live-container check below is unambiguous (independent origin from the
PWA, so a different value is correct and harmless):
```bash
sed -i "s/const CACHE_NAME = '.*';/const CACHE_NAME = 'macro-tracker-prod-v1';/" $PROD/sw.js
grep -n CACHE_NAME $PROD/sw.js     # confirm it now reads macro-tracker-prod-v1
```

---

## STEP 3 — Update production's nginx.conf (EDIT — keep the production proxy target)
Overwrite `$PROD/nginx.conf` with exactly the following. Note the proxy target is
`macro-tracker-api` (production), NOT `-pwa`. The only additions vs the old production config
are the `= /sw.js` and `= /manifest.json` location blocks needed to serve PWA assets.
```nginx
server {
    listen 80;
    root /usr/share/nginx/html;
    index index.html;

    location = /sw.js {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Service-Worker-Allowed "/";
        try_files $uri =404;
    }

    location = /manifest.json {
        add_header Cache-Control "no-cache";
        try_files $uri =404;
    }

    location /api/ {
        proxy_pass http://macro-tracker-api:3001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /health {
        proxy_pass http://macro-tracker-api:3001/health;
    }

    location / {
        try_files $uri $uri/ /index.html;
    }
}
```
After writing it, assert the target is correct and the PWA target is absent:
```bash
grep -n "proxy_pass" $PROD/nginx.conf
grep -q "macro-tracker-api-pwa" $PROD/nginx.conf && { echo "FATAL: PWA target leaked into prod nginx"; exit 1; } || echo "OK: prod proxy target preserved"
```

---

## STEP 4 — Update production's Dockerfile to ship the new assets
The current production Dockerfile only copies `nginx.conf` + `index.html`. Overwrite
`$PROD/Dockerfile` with exactly:
```dockerfile
FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
COPY sw.js /usr/share/nginx/html/sw.js
COPY manifest.json /usr/share/nginx/html/manifest.json
COPY 2515263.png /usr/share/nginx/html/2515263.png
COPY 1047711.png /usr/share/nginx/html/1047711.png
EXPOSE 80
```

---

## STEP 5 — Commit and push to Gitea (source of truth)
```bash
cd $REPO
git add tony-macro-tracker/frontend
git status                          # CONFIRM: only files under tony-macro-tracker/frontend/ are staged.
                                    # If anything under tony-macro-tracker-pwa/ appears, STOP.
git commit -m "Promote PWA frontend code to production (segregation preserved)"
git push origin master
```

> If you are NOT on the Pi (`uname -m` != aarch64): stop here. Run Steps 6–7 on the Pi after
> `git pull`. Do not build on x86.

---

## STEP 6 — Build, gate, push, deploy (RUN ON THE PI — ARM64 ONLY)
Scope: production frontend image `:latest` only.
```bash
# 6a. Build (this is the step that turns new source into a new image)
cd $REPO/tony-macro-tracker
sudo docker build --no-cache -t tonybooom/macro-tracker-frontend:latest ./frontend

# 6b. GATE before pushing — the local image must contain the new code
sudo docker run --rm tonybooom/macro-tracker-frontend:latest grep -n CACHE_NAME /usr/share/nginx/html/sw.js
#   EXPECT: macro-tracker-prod-v1
sudo docker run --rm tonybooom/macro-tracker-frontend:latest ls /usr/share/nginx/html/
#   EXPECT to see: index.html  sw.js  manifest.json  1047711.png  2515263.png
#   If CACHE_NAME is wrong or files missing -> the build did not read expected source. STOP and fix.

# 6c. Push — output MUST show layers uploading and a NEW digest.
#     If every line says "Layer already exists", nothing was rebuilt -> go back to 6a.
sudo docker push tonybooom/macro-tracker-frontend:latest

# 6d. Force the new image into the running container (same-tag re-pull trap: a present tag is
#     not re-pulled by `compose up`, so force-recreate from the freshly built local image)
cd $REPO/tony-macro-tracker
sudo docker compose up -d --force-recreate
```

---

## STEP 7 — Verify the LIVE state (the only test that counts)

### 7a. Production now serves the new code
```bash
sudo docker exec macro-tracker-frontend grep -n CACHE_NAME /usr/share/nginx/html/sw.js
#   EXPECT: macro-tracker-prod-v1
sudo docker exec macro-tracker-frontend ls /usr/share/nginx/html/
#   EXPECT: index.html sw.js manifest.json 1047711.png 2515263.png
curl -I http://192.168.1.118:8069/sw.js          # 200
curl -I http://192.168.1.118:8069/manifest.json  # 200
```

### 7b. Production segregation intact — its nginx still reaches the PRODUCTION api/db
```bash
curl -s http://192.168.1.118:8069/health         # healthy response via macro-tracker-api
```

### 7c. PWA-TEST is completely UNTOUCHED (compare to Step 0 baseline)
```bash
sudo docker exec macro-tracker-frontend-pwa grep -n CACHE_NAME /usr/share/nginx/html/sw.js
#   EXPECT: still macro-tracker-v4 (unchanged)
curl -I http://192.168.1.118:8070/sw.js          # still 200, PWA still serving
sudo docker exec macro-tracker-db-pwa psql -U macrouser -d macrotracker -c "SELECT count(*) FROM log_entries;"
#   EXPECT: identical count to Step 0
```

### 7d. Confirm the shared API image was not rebuilt
```bash
sudo docker images tonybooom/macro-tracker-api:latest
#   The CREATED timestamp should be OLD (predates this task). If it is new, the API was
#   rebuilt by mistake -> investigate before considering this done.
```

---

## SUCCESS CRITERIA (all must hold)
- [ ] `macro-tracker-frontend` (prod) serves sw.js with `CACHE_NAME = macro-tracker-prod-v1`, plus manifest.json + both icons.
- [ ] `http://192.168.1.118:8069/health` returns healthy (prod nginx still proxies to `macro-tracker-api`).
- [ ] Prod `nginx.conf` contains `macro-tracker-api` and does NOT contain `macro-tracker-api-pwa`.
- [ ] PWA-TEST sw.js CACHE_NAME is still `macro-tracker-v4`; port 8070 still serves; PWA DB row count unchanged.
- [ ] `macro-tracker-frontend:feature-pwa` and `macro-tracker-api:latest` images were NOT rebuilt/pushed.
- [ ] Only files under `tony-macro-tracker/frontend/` were changed in the commit.

---

## Rollback (if production breaks)
```bash
sudo docker tag tonybooom/macro-tracker-frontend:pre-pwa-backup tonybooom/macro-tracker-frontend:latest
cd $REPO/tony-macro-tracker && sudo docker compose up -d --force-recreate
# then revert the repo commit: git revert <commit> && git push origin master
```

---

## NOTES — read before running
- **Known bugs are carried over as-is.** This task copies the *current* PWA-TEST frontend,
  which still contains the unpatched issues identified earlier: the backup call uses the 2.5s
  abort timeout (so backups can falsely report failure and flip the app offline), `addEntry`
  can drop an entry when `isOnline` is stale-true (entry never enqueued), and `init()` does not
  flush a non-empty offline queue on reopen. If you want production to launch *without* these,
  fix them in PWA-TEST first, verify, then run this promotion. Faithfully copying first is the
  intended default here.
- **Database segregation is unaffected by this task.** The frontend never selects a database;
  the nginx → API → DB chain is fixed by each app's compose file. As long as the prod nginx
  proxy target and both compose files are left alone, prod writes only to `macro-tracker-db`
  and PWA writes only to `macro-tracker-db-pwa`.
- **Different CACHE_NAME between the two apps is correct**, not a mistake — they are separate
  origins (8069 vs 8070) with independent service-worker caches.

---

## Appendix — Logic-only variant (production stays a plain web app, NOT a PWA)
Use this *instead of* Steps 2–4 if you do not want a service worker in production:
- Step 1: copy **only** `index.html` (skip sw.js, manifest.json, icons).
- Skip Step 2 (no sw.js to version).
- Step 3: leave production `nginx.conf` unchanged.
- Step 4: leave production `Dockerfile` unchanged.
- Then in the copied `index.html`, neutralise the service-worker registration so it doesn't
  try to fetch a non-existent `/sw.js` (find the `navigator.serviceWorker.register(...)` call
  and guard or remove it).
- Steps 5–7 proceed the same, except the gate/verify token is no longer CACHE_NAME — instead
  grep for a distinctive new string you add to index.html (e.g. a build comment) to prove the
  new file is live, since CACHE_NAME won't exist.
- Trade-off: production loses offline support and installability. Given the offline logic is
  the main reason the PWA code exists, full parity (the main steps) is usually what you want.
