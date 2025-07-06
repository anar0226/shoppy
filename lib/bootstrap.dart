import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'core/services/order_fulfillment_service.dart';
import 'core/config/environment_config.dart';
import 'features/notifications/fcm_service.dart';
import 'main.dart' show ShopUBApp; // Re-use existing root widget
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Initialise services & run the Flutter app.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Flutter error handling
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  // Catch all uncaught async errors
  runZonedGuarded(() async {
    await _internalBootstrap();
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error');
  });
}

// Internal bootstrap moved here to allow zone wrapper
Future<void> _internalBootstrap() async {
  // 1. Load environment file
  await dotenv.load(fileName: 'assets/env/prod.env');

  // 2. Firebase
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['F_API_KEY']!,
      appId: dotenv.env['F_APP_ID']!,
      projectId: dotenv.env['F_PROJECT_ID']!,
      messagingSenderId: dotenv.env['F_SENDER_ID']!,
    ),
  );

  // 3. Performance Monitoring
  await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);

  // 4. FCM background handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 5. Payment services
  await _initializePaymentServices();

  runApp(const ShopUBApp());
}

/// Order-fulfilment / QPay init (copied from old main.dart)
Future<void> _initializePaymentServices() async {
  try {
    final fulfillmentService = OrderFulfillmentService();
    await fulfillmentService.initialize(
      qpayUsername: EnvironmentConfig.qpayUsername,
      qpayPassword: EnvironmentConfig.qpayPassword,
      ubcabApiKey: EnvironmentConfig.ubcabApiKey,
      ubcabMerchantId: EnvironmentConfig.ubcabMerchantId,
      ubcabProduction: EnvironmentConfig.ubcabProduction,
    );
  } catch (_) {
    // Ignore failures – payment UI will show its own error states.
  }
}
