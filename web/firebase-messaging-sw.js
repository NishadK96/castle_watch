importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAfvBOcUXT1M51ik2_vbGKmoCF65de0Fy4',
  authDomain: 'castle-watch-29837.firebaseapp.com',
  projectId: 'castle-watch-29837',
  storageBucket: 'castle-watch-29837.firebasestorage.app',
  messagingSenderId: '112580489904',
  appId: '1:112580489904:web:2a7e8492af38f428d8c175',
});

firebase.messaging();

self.addEventListener('notificationclick', (event) => {
  const data = event.notification.data || {};
  if (!data.sessionId || !event.action) return;
  event.notification.close();
  event.waitUntil((async () => {
    const targetUrl = new URL('/#/play?quick=1', self.location.origin).href;
    const windows = await clients.matchAll({
      type: 'window',
      includeUncontrolled: true
    });
    if (windows.length > 0) {
      if ('navigate' in windows[0]) {
        await windows[0].navigate(targetUrl);
      }
      await windows[0].focus();
    } else {
      await clients.openWindow(targetUrl);
    }
  })());
});
