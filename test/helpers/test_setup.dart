import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:network_image_mock/network_image_mock.dart';

/// Test setup utilities for the Shoppy application
class TestSetup {
  static FakeFirebaseFirestore? _fakeFirestore;
  static MockFirebaseAuth? _mockAuth;

  /// Get a fake Firestore instance for testing
  static FakeFirebaseFirestore get fakeFirestore {
    _fakeFirestore ??= FakeFirebaseFirestore();
    return _fakeFirestore!;
  }

  /// Get a mock Firebase Auth instance for testing
  static MockFirebaseAuth get mockAuth {
    _mockAuth ??= MockFirebaseAuth();
    return _mockAuth!;
  }

  /// Reset all test instances
  static void reset() {
    _fakeFirestore = null;
    _mockAuth = null;
  }

  /// Create a test app with mocked dependencies
  static Widget createTestApp({
    required Widget child,
    List<NavigatorObserver> navigatorObservers = const [],
  }) {
    return MaterialApp(
      home: child,
      navigatorObservers: navigatorObservers,
      debugShowCheckedModeBanner: false,
    );
  }

  /// Create a test app with network image mocking
  static Widget createTestAppWithNetworkImages({
    required Widget child,
    List<NavigatorObserver> navigatorObservers = const [],
  }) {
    return NetworkImageMock(
      child: MaterialApp(
        home: child,
        navigatorObservers: navigatorObservers,
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  /// Pump widget with network image mocking
  static Future<void> pumpWidgetWithNetworkImages(
    WidgetTester tester,
    Widget widget, {
    Duration? duration,
  }) async {
    await mockNetworkImagesFor(() async {
      await tester.pumpWidget(widget);
      if (duration != null) {
        await tester.pump(duration);
      }
    });
  }

  /// Wait for async operations to complete
  static Future<void> waitForAsync(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  /// Tap a widget and wait for animations
  static Future<void> tapAndWait(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Enter text and wait for animations
  static Future<void> enterTextAndWait(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  /// Find text and verify it exists
  static Finder findText(String text) {
    return find.text(text);
  }

  /// Find widget by key
  static Finder findWidgetByKey(Key key) {
    return find.byKey(key);
  }

  /// Find widget by type
  static Finder findWidgetByType<T extends Widget>() {
    return find.byType(T);
  }
}
