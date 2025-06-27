import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _fcmTokensCollection = 'fcm_tokens';
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
  );

  String? _currentToken;
  bool _isInitialized = false;

  // Callbacks for navigation
  Function(String route, Map<String, dynamic>? arguments)? _onNotificationTap;

  /// Initialize FCM service
  Future<void> initialize({
    Function(String route, Map<String, dynamic>? arguments)? onNotificationTap,
  }) async {
    if (_isInitialized) return;

    _onNotificationTap = onNotificationTap;

    try {
      // Initialize local notifications
      await _initializeLocalNotifications();

      // Request permissions
      await _requestPermissions();

      // Configure FCM
      await _configureFCM();

      // Get and save FCM token
      await _initializeToken();

      // Setup listeners
      _setupMessageListeners();

      _isInitialized = true;
      debugPrint('✅ FCM Service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing FCM Service: $e');
    }
  }

  /// Initialize local notifications
  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
  }

  /// Request notification permissions
  Future<bool> _requestPermissions() async {
    if (Platform.isIOS) {
      final settings = await _firebaseMessaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } else {
      // Android 13+ requires explicit permission
      if (Platform.isAndroid) {
        final status = await Permission.notification.request();
        return status == PermissionStatus.granted;
      }
      return true;
    }
  }

  /// Configure FCM settings
  Future<void> _configureFCM() async {
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  /// Initialize and save FCM token
  Future<void> _initializeToken() async {
    try {
      _currentToken = await _firebaseMessaging.getToken();
      if (_currentToken != null) {
        await _saveTokenToFirestore(_currentToken!);
        debugPrint('📱 FCM Token: $_currentToken');
      }
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
    }
  }

  /// Save FCM token to Firestore
  Future<void> _saveTokenToFirestore(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection(_fcmTokensCollection)
          .doc(user.uid)
          .set({
        'token': token,
        'userId': user.uid,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'isActive': true,
      }, SetOptions(merge: true));

      // Also save token in user document for easy access
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('💾 FCM token saved to Firestore');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Setup message listeners
  void _setupMessageListeners() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message taps
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundMessageTap);

    // Handle token refresh
    _firebaseMessaging.onTokenRefresh.listen(_onTokenRefresh);

    // Handle initial message (when app is opened from terminated state)
    _handleInitialMessage();
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('🔔 Foreground message received: ${message.messageId}');

    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      // Show local notification when app is in foreground
      await _showLocalNotification(
        title: notification.title ?? 'New Notification',
        body: notification.body ?? '',
        data: data,
      );
    }

    // Process notification data
    await _processNotificationData(data);
  }

  /// Handle background message tap
  void _handleBackgroundMessageTap(RemoteMessage message) {
    debugPrint('🔔 Background message tapped: ${message.messageId}');
    _navigateFromNotification(message.data);
  }

  /// Handle initial message (from terminated state)
  Future<void> _handleInitialMessage() async {
    final RemoteMessage? initialMessage =
        await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🔔 Initial message: ${initialMessage.messageId}');
      _navigateFromNotification(initialMessage.data);
    }
  }

  /// Handle token refresh
  void _onTokenRefresh(String token) {
    _currentToken = token;
    _saveTokenToFirestore(token);
    debugPrint('🔄 FCM token refreshed: $token');
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    final BigTextStyleInformation bigTextStyleInformation =
        BigTextStyleInformation(
      body,
      htmlFormatBigText: true,
      contentTitle: title,
      htmlFormatContentTitle: true,
    );

    final AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: bigTextStyleInformation,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iOSNotificationDetails =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
      iOS: iOSNotificationDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: data != null ? jsonEncode(data) : null,
    );
  }

  /// Handle notification response (tap)
  void _onNotificationResponse(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _navigateFromNotification(data);
      } catch (e) {
        debugPrint('❌ Error parsing notification payload: $e');
      }
    }
  }

  /// Process notification data for analytics and actions
  Future<void> _processNotificationData(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Save notification interaction
      await FirebaseFirestore.instance
          .collection('notification_analytics')
          .add({
        'userId': user.uid,
        'type': data['type'] ?? 'unknown',
        'action': 'received',
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error processing notification data: $e');
    }
  }

  /// Navigate based on notification data
  void _navigateFromNotification(Map<String, dynamic> data) {
    if (_onNotificationTap == null) return;

    final type = data['type'] as String?;
    final arguments = Map<String, dynamic>.from(data);

    switch (type) {
      case 'orderTracking':
        _onNotificationTap!('/orders', arguments);
        break;
      case 'priceDrops':
      case 'newDrops':
        final productId = data['productId'] as String?;
        if (productId != null) {
          _onNotificationTap!('/product', {'productId': productId});
        }
        break;
      case 'offers':
        _onNotificationTap!('/offers', arguments);
        break;
      default:
        _onNotificationTap!('/home', arguments);
    }

    // Track notification tap
    _trackNotificationTap(data);
  }

  /// Track notification tap for analytics
  Future<void> _trackNotificationTap(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('notification_analytics')
          .add({
        'userId': user.uid,
        'type': data['type'] ?? 'unknown',
        'action': 'tapped',
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ Error tracking notification tap: $e');
    }
  }

  /// Send push notification to specific user
  static Future<void> sendPushNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      // Get user's FCM token
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (!userDoc.exists) {
        debugPrint('❌ User not found: $userId');
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      final fcmToken = userData['fcmToken'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('❌ No FCM token found for user: $userId');
        return;
      }

      // Create notification payload
      final payload = {
        'notification': {
          'title': title,
          'body': body,
        },
        'data': data ?? {},
        'token': fcmToken,
      };

      // Send via Cloud Function (you'll need to implement this)
      // For now, we'll save it to a collection for Cloud Functions to process
      await FirebaseFirestore.instance.collection('notification_queue').add({
        'userId': userId,
        'payload': payload,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('📤 Push notification queued for user: $userId');
    } catch (e) {
      debugPrint('❌ Error sending push notification: $e');
    }
  }

  /// Send push notification to multiple users
  static Future<void> sendPushNotificationToUsers({
    required List<String> userIds,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    for (final userId in userIds) {
      await sendPushNotification(
        userId: userId,
        title: title,
        body: body,
        data: data,
      );
    }
  }

  /// Check notification permission status
  Future<bool> isNotificationPermissionGranted() async {
    if (Platform.isIOS) {
      final settings = await _firebaseMessaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    } else {
      final status = await Permission.notification.status;
      return status == PermissionStatus.granted;
    }
  }

  /// Request notification permission
  Future<bool> requestNotificationPermission() async {
    return await _requestPermissions();
  }

  /// Get current FCM token
  String? get currentToken => _currentToken;

  /// Get notification settings
  Future<NotificationSettings> getNotificationSettings() async {
    return await _firebaseMessaging.getNotificationSettings();
  }

  /// Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _firebaseMessaging.subscribeToTopic(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Error unsubscribing from topic: $e');
    }
  }

  /// Clear notification badges (iOS)
  Future<void> clearBadge() async {
    // Badge clearing functionality will be implemented later
    debugPrint('📛 Badge clearing requested');
  }

  /// Dispose resources
  void dispose() {
    // Cleanup if needed
  }
}

// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('🔔 Background message received: ${message.messageId}');

  // Process background message
  // Add any background processing logic here
}
