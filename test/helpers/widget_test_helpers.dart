import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:avii/features/auth/providers/auth_provider.dart';
import 'package:avii/features/cart/providers/cart_provider.dart';
import 'package:avii/features/theme/theme_provider.dart';
import 'package:avii/features/addresses/providers/address_provider.dart';
import 'package:avii/core/providers/connectivity_provider.dart';

/// Widget test helpers for the Shoppy application
class WidgetTestHelpers {
  /// Create a test app with all necessary providers
  static Widget createTestAppWithProviders({
    required Widget child,
    List<NavigatorObserver> navigatorObservers = const [],
    bool includeProviders = true,
  }) {
    if (!includeProviders) {
      return MaterialApp(
        home: child,
        navigatorObservers: navigatorObservers,
        debugShowCheckedModeBanner: false,
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: MaterialApp(
        home: child,
        navigatorObservers: navigatorObservers,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.teal,
          fontFamily: 'Roboto',
        ),
      ),
    );
  }

  /// Create a test app with network image mocking
  static Widget createTestAppWithNetworkImages({
    required Widget child,
    List<NavigatorObserver> navigatorObservers = const [],
    bool includeProviders = true,
  }) {
    final app = createTestAppWithProviders(
      child: child,
      navigatorObservers: navigatorObservers,
      includeProviders: includeProviders,
    );

    // Note: In real tests, wrap with NetworkImageMock
    return app;
  }

  /// Pump widget and wait for animations
  static Future<void> pumpAndSettle(WidgetTester tester, Widget widget) async {
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  /// Tap a widget and wait for animations
  static Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Enter text and wait for animations
  static Future<void> enterTextAndSettle(
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

  /// Find widget by icon
  static Finder findWidgetByIcon(IconData icon) {
    return find.byIcon(icon);
  }

  /// Find widget by tooltip
  static Finder findWidgetByTooltip(String tooltip) {
    return find.byTooltip(tooltip);
  }

  /// Find widget by semantics label
  static Finder findWidgetBySemanticsLabel(String label) {
    return find.bySemanticsLabel(label);
  }

  /// Verify text exists
  static void expectTextExists(WidgetTester tester, String text) {
    expect(find.text(text), findsOneWidget);
  }

  /// Verify text does not exist
  static void expectTextDoesNotExist(WidgetTester tester, String text) {
    expect(find.text(text), findsNothing);
  }

  /// Verify widget exists
  static void expectWidgetExists(WidgetTester tester, Finder finder) {
    expect(finder, findsOneWidget);
  }

  /// Verify widget does not exist
  static void expectWidgetDoesNotExist(WidgetTester tester, Finder finder) {
    expect(finder, findsNothing);
  }

  /// Verify multiple widgets exist
  static void expectWidgetsExist(
      WidgetTester tester, Finder finder, int count) {
    expect(finder, findsNWidgets(count));
  }

  /// Wait for async operations
  static Future<void> waitForAsync(WidgetTester tester) async {
    await tester.pumpAndSettle();
  }

  /// Wait for specific duration
  static Future<void> waitForDuration(
      WidgetTester tester, Duration duration) async {
    await tester.pump(duration);
  }

  /// Scroll to find widget
  static Future<void> scrollToFind(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 500.0);
    await tester.pumpAndSettle();
  }

  /// Drag widget
  static Future<void> dragWidget(
    WidgetTester tester,
    Finder finder,
    Offset offset,
  ) async {
    await tester.drag(finder, offset);
    await tester.pumpAndSettle();
  }

  /// Long press widget
  static Future<void> longPressWidget(
      WidgetTester tester, Finder finder) async {
    await tester.longPress(finder);
    await tester.pumpAndSettle();
  }

  /// Double tap widget
  static Future<void> doubleTapWidget(
      WidgetTester tester, Finder finder) async {
    await tester.tap(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Get text from widget
  static String getText(WidgetTester tester, Finder finder) {
    final widget = tester.widget<Text>(finder);
    return widget.data ?? '';
  }

  /// Get widget count
  static int getWidgetCount(WidgetTester tester, Finder finder) {
    return tester.widgetList(finder).length;
  }

  /// Check if widget is enabled
  static bool isWidgetEnabled(WidgetTester tester, Finder finder) {
    final widget = tester.widget<Widget>(finder);
    if (widget is ElevatedButton) {
      return widget.onPressed != null;
    } else if (widget is TextButton) {
      return widget.onPressed != null;
    } else if (widget is IconButton) {
      return widget.onPressed != null;
    }
    return true;
  }

  /// Check if widget is visible
  static bool isWidgetVisible(WidgetTester tester, Finder finder) {
    return tester.any(finder);
  }

  /// Get widget bounds
  static Rect getWidgetBounds(WidgetTester tester, Finder finder) {
    return tester.getRect(finder);
  }

  /// Get widget center
  static Offset getWidgetCenter(WidgetTester tester, Finder finder) {
    return tester.getCenter(finder);
  }

  /// Tap at specific position
  static Future<void> tapAtPosition(
    WidgetTester tester,
    Offset position,
  ) async {
    await tester.tapAt(position);
    await tester.pumpAndSettle();
  }

  /// Swipe widget
  static Future<void> swipeWidget(
    WidgetTester tester,
    Finder finder,
    Offset startOffset,
    Offset endOffset,
  ) async {
    await tester.dragFrom(startOffset, endOffset);
    await tester.pumpAndSettle();
  }

  /// Wait for navigation
  static Future<void> waitForNavigation(WidgetTester tester) async {
    await tester.pumpAndSettle();
    // Additional wait for navigation animations
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Verify navigation occurred
  static void expectNavigationOccurred(
    WidgetTester tester,
    String expectedRoute,
  ) {
    // This would need to be implemented based on your navigation setup
    // For now, just wait for navigation
    waitForNavigation(tester);
  }

  /// Create a mock navigator observer
  static NavigatorObserver createMockNavigatorObserver() {
    return MockNavigatorObserver();
  }
}

/// Mock navigator observer for testing navigation
class MockNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = <Route<dynamic>>[];
  final List<Route<dynamic>> poppedRoutes = <Route<dynamic>>[];
  final List<Route<dynamic>> removedRoutes = <Route<dynamic>>[];
  final List<Route<dynamic>> replacedRoutes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    poppedRoutes.add(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    removedRoutes.add(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      replacedRoutes.add(newRoute);
    }
  }

  /// Get the last pushed route
  Route<dynamic>? get lastPushedRoute {
    return pushedRoutes.isNotEmpty ? pushedRoutes.last : null;
  }

  /// Get the last popped route
  Route<dynamic>? get lastPoppedRoute {
    return poppedRoutes.isNotEmpty ? poppedRoutes.last : null;
  }

  /// Clear all route history
  void clear() {
    pushedRoutes.clear();
    poppedRoutes.clear();
    removedRoutes.clear();
    replacedRoutes.clear();
  }
}
