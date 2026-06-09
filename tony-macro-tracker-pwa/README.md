# Macro Tracker PWA — Feature Branch

Offline-capable PWA version for testing before promoting to production.

## What's different from the main app

- Service worker caches the app shell — loads offline after first visit
- IndexedDB queue stores changes made offline
- Auto-syncs queue when Pi is detected on home network (polls every 30s)
- PWA install banner on Android Chrome
- Isolated Docker network — won't interfere with production app

## Deploy to Pi

### 1. Copy folder into your app store repo
```bash
cp -r tony-macro-tracker-pwa/ ~/umbrel/app-stores/fazle1337-tony-umbrel-192-6304cbed/
```

### 2. Commit and push to Gitea
```bash
cd ~/umbrel/app-stores/fazle1337-tony-umbrel-192-6304cbed/
git add tony-macro-tracker-pwa/
git commit -m "feat: add PWA beta app"
git push origin master
```

### 3. Pull on Pi and build frontend image
```bash
cd ~/umbrel/app-stores/fazle1337-tony-umbrel-192-6304cbed
git pull origin master

cd tony-macro-tracker-pwa
sudo docker build --no-cache -t tonybooom/macro-tracker-frontend:feature-pwa ./frontend

# Verify all files are in the image
sudo docker run --rm tonybooom/macro-tracker-frontend:feature-pwa ls /usr/share/nginx/html/
# Should show: 50x.html  index.html  manifest.json  sw.js

sudo docker push tonybooom/macro-tracker-frontend:feature-pwa
```

### 4. Install from Umbrel UI
Refresh your app store in Umbrel and install "Macro Tracker (PWA beta)".

### 5. Verify PWA files are served
```bash
curl -I http://192.168.1.118:8070/sw.js        # should be 200
curl -I http://192.168.1.118:8070/manifest.json # should be 200
```

### 6. Install on Android
Open `http://192.168.1.118:8070` in Chrome → banner appears → tap Install.

## Promoting to production

When happy with the PWA version:
1. Copy frontend files into `tony-macro-tracker/frontend/`
2. Rebuild `tonybooom/macro-tracker-frontend:latest`
3. Push and restart production app
4. Uninstall `tony-macro-tracker-pwa` from Umbrel
