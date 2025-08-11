/* eslint-disable no-undef */
// Firebase Messaging service worker for web push notifications

importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.0/firebase-messaging-compat.js');

// IMPORTANT: Keep this config in sync with lib/firebase_options.dart (web)
firebase.initializeApp({
  apiKey: 'AIzaSyBv9U2CdHSEa5PBBlYnYulgG1cRxQfbhwo',
  appId: '1:110394685689:web:a5d998cdc2fc3b0842ca28',
  messagingSenderId: '110394685689',
  projectId: 'shoppy-6d81f',
  authDomain: 'shoppy-6d81f.firebaseapp.com',
  storageBucket: 'shoppy-6d81f.firebasestorage.app',
  measurementId: 'G-BCGNM9C9ED',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  const notificationTitle = payload.notification?.title || 'New Notification';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/Icon-192.png',
    data: payload.data || {},
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Optional: handle notification click to focus client
self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const targetUrl = event.notification?.data?.link || '/';
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (const client of clientList) {
        if ('focus' in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
}); 