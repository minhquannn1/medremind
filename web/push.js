// Dose-reminder push, called from Dart. All the browser-API ceremony lives
// here; Dart passes the auth token and language and gets a status string.
(function () {
  function b64ToUint8(base64) {
    const padding = '='.repeat((4 - (base64.length % 4)) % 4);
    const raw = atob((base64 + padding).replace(/-/g, '+').replace(/_/g, '/'));
    return Uint8Array.from(raw, (c) => c.charCodeAt(0));
  }

  async function enable(token, lang, onlyIfGranted) {
    if (!('serviceWorker' in navigator) || !('PushManager' in window) ||
        typeof Notification === 'undefined') {
      return 'unsupported';
    }
    if (onlyIfGranted && Notification.permission !== 'granted') return 'skipped';
    const permission = await Notification.requestPermission();
    if (permission !== 'granted') return 'denied';

    const reg = await navigator.serviceWorker.register('push_sw.js', {
      scope: './push-scope/',
    });
    // Wait for THIS registration's worker. navigator.serviceWorker.ready is
    // the page's root-scope registration — Flutter's caching worker — and
    // awaiting it stalled sign-in behind a 30MB precache on first load.
    const worker = reg.installing || reg.waiting || reg.active;
    if (worker && worker.state !== 'activated') {
      await new Promise((resolve) => {
        const done = () => resolve();
        worker.addEventListener('statechange', () => {
          if (worker.state === 'activated' || worker.state === 'redundant') done();
        });
        setTimeout(done, 10000);
      });
    }

    const keyRes = await fetch('api/push/public-key');
    const { key } = await keyRes.json();

    const sub =
      (await reg.pushManager.getSubscription()) ||
      (await reg.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: b64ToUint8(key),
      }));

    const res = await fetch('api/push/subscribe', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: 'Bearer ' + token,
      },
      body: JSON.stringify({
        subscription: sub.toJSON(),
        timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
        lang: lang,
      }),
    });
    return res.ok ? 'enabled' : 'server_rejected';
  }

  async function disable(token) {
    try {
      const reg = await navigator.serviceWorker.getRegistration('./push-scope/');
      const sub = reg && (await reg.pushManager.getSubscription());
      if (!sub) return 'none';
      await fetch('api/push/subscribe', {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          Authorization: 'Bearer ' + token,
        },
        body: JSON.stringify({ endpoint: sub.endpoint }),
      });
      await sub.unsubscribe();
      return 'disabled';
    } catch (_) {
      return 'error';
    }
  }

  window.medolyPush = { enable: enable, disable: disable };
})();
