const CACHE_NAME = 'careclock-v1.0.0';
const STATIC_CACHE = 'careclock-static-v1.0.0';
const DYNAMIC_CACHE = 'careclock-dynamic-v1.0.0';

const urlsToCache = [
    '/baby-care-scheduler.html',
    '/manifest.json',
    'https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap',
    'https://cdn.jsdelivr.net/npm/chart.js'
];

// Install event - cache static assets
self.addEventListener('install', event => {
    console.log('Service Worker installing...');
    event.waitUntil(
        caches.open(STATIC_CACHE)
            .then(cache => {
                console.log('Caching static assets');
                return cache.addAll(urlsToCache);
            })
            .then(() => self.skipWaiting())
    );
});

// Activate event - clean up old caches
self.addEventListener('activate', event => {
    console.log('Service Worker activating...');
    event.waitUntil(
        caches.keys().then(cacheNames => {
            return Promise.all(
                cacheNames.map(cacheName => {
                    if (cacheName !== STATIC_CACHE && cacheName !== DYNAMIC_CACHE) {
                        console.log('Deleting old cache:', cacheName);
                        return caches.delete(cacheName);
                    }
                })
            );
        }).then(() => self.clients.claim())
    );
});

// Fetch event - network first, then cache strategy
self.addEventListener('fetch', event => {
    const { request } = event;
    
    // Skip non-GET requests
    if (request.method !== 'GET') {
        return;
    }
    
    // Handle different request types
    if (urlsToCache.some(url => request.url.includes(url.replace('/', '')))) {
        // Static assets - cache first
        event.respondWith(cacheFirst(request));
    } else if (request.url.includes('/api/')) {
        // API requests - network first
        event.respondWith(networkFirst(request));
    } else {
        // Other requests - stale while revalidate
        event.respondWith(staleWhileRevalidate(request));
    }
});

// Cache strategies
async function cacheFirst(request) {
    const cachedResponse = await caches.match(request);
    return cachedResponse || fetch(request);
}

async function networkFirst(request) {
    try {
        const networkResponse = await fetch(request);
        if (networkResponse.ok) {
            const cache = await caches.open(DYNAMIC_CACHE);
            cache.put(request, networkResponse.clone());
        }
        return networkResponse;
    } catch (error) {
        console.log('Network failed, trying cache:', error);
        return caches.match(request);
    }
}

async function staleWhileRevalidate(request) {
    const cache = await caches.open(DYNAMIC_CACHE);
    const cachedResponse = await cache.match(request);
    
    const fetchPromise = fetch(request).then(response => {
        if (response.ok) {
            cache.put(request, response.clone());
        }
        return response;
    }).catch(() => cachedResponse);
    
    return cachedResponse || fetchPromise;
}

self.addEventListener('notificationclick', event => {
    event.notification.close();
    
    if (event.action === 'complete') {
        event.waitUntil(
            clients.matchAll().then(clients => {
                if (clients.length > 0) {
                    clients[0].postMessage({
                        action: 'notification-click',
                        type: 'complete',
                        itemId: event.notification.tag.replace('careclock-', '')
                    });
                    clients[0].focus();
                }
            })
        );
    } else if (event.action === 'snooze') {
        event.waitUntil(
            clients.matchAll().then(clients => {
                if (clients.length > 0) {
                    clients[0].postMessage({
                        action: 'notification-click',
                        type: 'snooze',
                        itemId: event.notification.tag.replace('careclock-', '')
                    });
                }
            })
        );
    } else {
        event.waitUntil(clients.openWindow('/baby-care-scheduler.html'));
    }
});

self.addEventListener('sync', event => {
    if (event.tag === 'background-sync') {
        event.waitUntil(doBackgroundSync());
    }
});

async function doBackgroundSync() {
    // Sync data when connection is restored
    console.log('Background sync triggered');
}
