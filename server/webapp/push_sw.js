// Push-only service worker, registered at its own scope so it never collides
// with Flutter's caching service worker at the root scope.
self.addEventListener('push', (event) => {
  let data = { title: 'Medoly', body: '', tag: 'dose' };
  try {
    data = { ...data, ...event.data.json() };
  } catch (_) { /* keep defaults */ }
  event.waitUntil(
    self.registration.showNotification(data.title, {
      body: data.body,
      tag: data.tag,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      renotify: true,
    }),
  );
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((list) => {
      const existing = list.find((c) => 'focus' in c);
      return existing ? existing.focus() : clients.openWindow('/');
    }),
  );
});
