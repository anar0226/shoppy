import 'package:flutter/material.dart';
import 'payment_timeout_countdown.dart';

/// Test widget to demonstrate the timeout countdown functionality
class TimeoutTestWidget extends StatefulWidget {
  const TimeoutTestWidget({super.key});

  @override
  State<TimeoutTestWidget> createState() => _TimeoutTestWidgetState();
}

class _TimeoutTestWidgetState extends State<TimeoutTestWidget> {
  bool _showCountdown = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeout Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_showCountdown) ...[
              const Text(
                'Timeout Countdown Test',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'This will test the 10-minute payment timeout countdown widget.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showCountdown = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'Start 10-Minute Countdown',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ] else ...[
              PaymentTimeoutCountdown(
                initialDuration: const Duration(minutes: 10),
                orderId: 'TEST_ORDER_123',
                onTimeout: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Timeout expired!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showCountdown = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'Reset',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
