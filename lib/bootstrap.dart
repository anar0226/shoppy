import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'core/services/order_fulfillment_service.dart';
import 'core/services/production_logger.dart';
import 'core/services/error_recovery_service.dart';
import 'core/config/environment_config.dart';
import 'features/notifications/fcm_service.dart';
import 'main.dart' show ShopUBApp;
import 'dart:async';

/// Initialise services & run the Flutter app.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global Flutter error handling with production logging
  FlutterError.onError = (details) {
    FlutterError.presentError(details);

    // Log to production logger (will be initialized later)
    Future.microtask(() async {
      await ProductionLogger.instance.error(
        'Flutter Error: ${details.exception}',
        error: details.exception,
        stackTrace: details.stack,
        context: {
          'library': details.library,
          'context': details.context?.toString(),
          'errorType': 'flutter_error',
        },
        isFatal: details.silent == false,
      );
    });
  };

  // Catch all uncaught async errors
  runZonedGuarded(() async {
    await _internalBootstrap();
  }, (error, stack) {
    // Log uncaught errors
    Future.microtask(() async {
      await ProductionLogger.instance.error(
        'Uncaught Error: $error',
        error: error,
        stackTrace: stack,
        context: {
          'errorType': 'uncaught_error',
          'zone': 'global',
        },
        isFatal: true,
      );
    });
  });
}

// Internal bootstrap moved here to allow zone wrapper
Future<void> _internalBootstrap() async {
  try {
    // 1. Load environment file
    await dotenv.load(fileName: 'assets/env/prod.env');

    // 2. Firebase initialization with error handling
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: dotenv.env['F_API_KEY']!,
        appId: dotenv.env['F_APP_ID']!,
        projectId: dotenv.env['F_PROJECT_ID']!,
        messagingSenderId: dotenv.env['F_SENDER_ID']!,
      ),
    );

    // 3. Initialize production logger
    await ProductionLogger.instance.initialize();
    await ProductionLogger.instance.info('App bootstrap started', context: {
      'environment':
          EnvironmentConfig.isProduction ? 'production' : 'development',
      'version': EnvironmentConfig.appVersion,
    });

    // 4. Performance Monitoring
    if (EnvironmentConfig.enablePerformanceMonitoring) {
      await FirebasePerformance.instance.setPerformanceCollectionEnabled(true);
      await ProductionLogger.instance.info('Performance monitoring enabled');
    }

    // 5. FCM background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await ProductionLogger.instance.info('FCM background handler configured');

    // 6. Performance optimization (removed - was unused)
    await ProductionLogger.instance.info('Performance optimization skipped');

    // 8. Payment services with enhanced error handling
    await _initializePaymentServices();

    await ProductionLogger.instance
        .info('App bootstrap completed successfully');

    // 9. Log startup completion with metrics
    await ProductionLogger.instance
        .businessEvent('app_startup_completed', data: {
      'recovery_stats': ErrorRecoveryService.instance.getRecoveryStats(),
      'environment':
          EnvironmentConfig.isProduction ? 'production' : 'development',
    });

    runApp(const ShopUBApp());
  } catch (error, stackTrace) {
    // Bootstrap failed - log the error and try to continue
    try {
      await ProductionLogger.instance.error(
        'Bootstrap failed',
        error: error,
        stackTrace: stackTrace,
        context: {
          'stage': 'bootstrap',
          'critical': true,
        },
        isFatal: true,
      );
    } catch (logError) {
      // Failed to log bootstrap error
    }

    // Try to run app anyway for better user experience
    runApp(const ShopUBApp());
  }
}

/// Order-fulfilment / QPay init (copied from old main.dart)
Future<void> _initializePaymentServices() async {
  try {
    final fulfillmentService = OrderFulfillmentService();
    await fulfillmentService.initialize(
      qpayUsername: EnvironmentConfig.qpayUsername,
      qpayPassword: EnvironmentConfig.qpayPassword,
    );

    await ProductionLogger.instance.info(
      'Payment services initialized successfully',
      context: {
        'service': 'OrderFulfillmentService',
        'stage': 'bootstrap',
      },
    );
  } catch (error, stackTrace) {
    // Log payment service initialization failure
    await ProductionLogger.instance.error(
      'Payment services initialization failed',
      error: error,
      stackTrace: stackTrace,
      context: {
        'service': 'OrderFulfillmentService',
        'stage': 'bootstrap',
        'impact': 'payment_features_degraded',
        'recovery': 'payment_ui_will_show_error_states',
      },
    );

    // Don't rethrow - allow app to continue with degraded payment functionality
    // Payment UI will handle errors gracefully when services are unavailable
  }
}
