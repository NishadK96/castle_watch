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
    try {
      const response = await fetch(
        `${data.supabaseUrl}/rest/v1/rpc/advance_play_session`,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'apikey': data.anonKey,
            'Authorization': `Bearer ${data.anonKey}`
          },
          body: JSON.stringify({
            p_session_id: data.sessionId,
            p_secret: data.secret,
            p_action: event.action
          })
        }
      );
      if (!response.ok) throw new Error(await response.text());
      const next = await response.json();
      if (next.status !== 'active') {
        await self.registration.showNotification('Play session complete', {
          body: next.status === 'completed'
            ? 'Every account in this session has been processed.'
            : 'The play session was stopped.',
          icon: 'icons/Icon-192.png',
          tag: 'castle-watch-play-session'
        });
        return;
      }
      await self.registration.showNotification(`Play ${next.current_account_name}`, {
        body: `Account ${next.position} of ${next.total}`,
        icon: 'icons/Icon-192.png',
        badge: 'icons/Icon-192.png',
        tag: 'castle-watch-play-session',
        renotify: true,
        requireInteraction: true,
        actions: [
          { action: 'played', title: 'Played & next' },
          { action: 'skip', title: 'Skip' },
          { action: 'stop', title: 'Stop' }
        ],
        data
      });
    } catch (_) {
      await self.registration.showNotification('Castle Watch action failed', {
        body: 'Open Castle Watch and restart the play session.',
        icon: 'icons/Icon-192.png',
        tag: 'castle-watch-play-session-error'
      });
    }
  })());
});
