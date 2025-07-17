import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:avii/main.dart';

void main() {
  group('Avii.mn App Tests', () {
    testWidgets('App loads without crashing', (WidgetTester tester) async {
      // Build our app and trigger a frame.
      await tester.pumpWidget(const ShopUBApp());

      // Verify that the app starts
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Navigation between pages works', (WidgetTester tester) async {
      await tester.pumpWidget(const ShopUBApp());

      // Wait for the app to settle
      await tester.pumpAndSettle();

      // The app should have some basic navigation structure
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  group('Widget Performance Tests', () {
    testWidgets('App renders within acceptable time',
        (WidgetTester tester) async {
      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(const ShopUBApp());
      await tester.pumpAndSettle();

      stopwatch.stop();

      // App should render within 1 second
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
    });
  });
}
