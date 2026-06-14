const CACHE_NAME = 'macro-tracker-v3';
const OFFLINE_DB = 'macro-tracker-offline';
const OFFLINE_QUEUE_STORE = 'sync-queue';
const SNAPSHOT_STORE = 'data-snapshot';

const STATIC_ASSETS = ['/', '/index.html'];

// ─── INSTALL ──────────────────────────────────────────────────────────────────
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => cache.addAll(STATIC_ASSETS))
      .then(() => self.skipWaiting())
  );
});

// ─── ACTIVATE ─────────────────────────────────────────────────────────────────
self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE_NAME).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

// ─── FETCH ────────────────────────────────────────────────────────────────────
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);

  // API calls — pass through, return offline error if failed
  if (url.pathname.startsWith('/api/') || url.pathname === '/health') {
    event.respondWith(
      fetch(event.request).catch(() =>
        new Response(JSON.stringify({ offline: true, error: 'Offline' }), {
          status: 503,
          headers: { 'Content-Type': 'application/json' }
        })
      )
    );
    return;
  }

  // Everything else — cache first, fallback to network, fallback to index.html
  event.respondWith(
    caches.match(event.request).then(cached => {
      if (cached) return cached;
      return fetch(event.request).then(response => {
        if (response.ok) {
          const clone = response.clone();
          caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
        }
        return response;
      }).catch(() => caches.match('/index.html'));
    })
  );
});

// ─── MESSAGES ─────────────────────────────────────────────────────────────────
self.addEventListener('message', event => {
  if (event.data === 'SKIP_WAITING') self.skipWaiting();
  if (event.data === 'SYNC_NOW') event.waitUntil(processQueue());
});

// ─── BACKGROUND SYNC ─────────────────────────────────────────────────────────
self.addEventListener('sync', event => {
  if (event.tag === 'macro-sync') event.waitUntil(processQueue());
});

async function processQueue() {
  const db = await openOfflineDB();
  const queue = await getAllFromStore(db, OFFLINE_QUEUE_STORE);
  if (!queue.length) return;
  const API_KEY = await getAPIKey(db);
  for (const item of queue) {
    try {
      const res = await fetch(item.url, {
        method: item.method,
        headers: { 'Content-Type': 'application/json', 'x-api-key': API_KEY },
        body: item.body ? JSON.stringify(item.body) : undefined
      });
      if (res.ok) await deleteFromStore(db, OFFLINE_QUEUE_STORE, item.id);
    } catch (e) { break; }
  }
  const clients = await self.clients.matchAll();
  clients.forEach(client => client.postMessage({ type: 'SYNC_COMPLETE' }));
}

// ─── INDEXEDDB HELPERS ────────────────────────────────────────────────────────
function openOfflineDB() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(OFFLINE_DB, 2);
    req.onupgradeneeded = e => {
      const db = e.target.result;
      if (!db.objectStoreNames.contains(OFFLINE_QUEUE_STORE)) {
        const store = db.createObjectStore(OFFLINE_QUEUE_STORE, { keyPath: 'id', autoIncrement: true });
        store.createIndex('timestamp', 'timestamp');
      }
      if (!db.objectStoreNames.contains(SNAPSHOT_STORE)) {
        db.createObjectStore(SNAPSHOT_STORE, { keyPath: 'key' });
      }
      if (!db.objectStoreNames.contains('config')) {
        db.createObjectStore('config', { keyPath: 'key' });
      }
    };
    req.onsuccess = e => resolve(e.target.result);
    req.onerror = e => reject(e.target.error);
  });
}

function getAllFromStore(db, storeName) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, 'readonly');
    const req = tx.objectStore(storeName).getAll();
    req.onsuccess = e => resolve(e.target.result);
    req.onerror = e => reject(e.target.error);
  });
}

function deleteFromStore(db, storeName, id) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(storeName, 'readwrite');
    const req = tx.objectStore(storeName).delete(id);
    req.onsuccess = () => resolve();
    req.onerror = e => reject(e.target.error);
  });
}

async function getAPIKey(db) {
  return new Promise(resolve => {
    const tx = db.transaction('config', 'readonly');
    const req = tx.objectStore('config').get('apiKey');
    req.onsuccess = e => resolve(e.target.result?.value || 'myapisecret123');
    req.onerror = () => resolve('myapisecret123');
  });
}
