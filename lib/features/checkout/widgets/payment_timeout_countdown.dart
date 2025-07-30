import 'package:flutter/material.dart';
import 'dart:async';

/// Widget to display a countdown timer for payment timeout
class PaymentTimeoutCountdown extends StatefulWidget {
  final Duration initialDuration;
  final VoidCallback? onTimeout;
  final String? orderId;

  const PaymentTimeoutCountdown({
    super.key,
    required this.initialDuration,
    this.onTimeout,
    this.orderId,
  });

  @override
  State<PaymentTimeoutCountdown> createState() =>
      _PaymentTimeoutCountdownState();
}

class _PaymentTimeoutCountdownState extends State<PaymentTimeoutCountdown> {
  late Timer _timer;
  late Duration _remainingTime;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.initialDuration;
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingTime.inSeconds > 0) {
            _remainingTime = _remainingTime - const Duration(seconds: 1);
          } else {
            _isExpired = true;
            timer.cancel();
            widget.onTimeout?.call();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatTime() {
    final minutes = _remainingTime.inMinutes;
    final seconds = _remainingTime.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Color _getColor() {
    if (_isExpired) return Colors.red;
    if (_remainingTime.inMinutes < 2) return Colors.orange;
    if (_remainingTime.inMinutes < 5) return Colors.yellow.shade700;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    if (_isExpired) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_off, color: Colors.red.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Төлбөрийн хугацаа дууссан',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Таны төлбөрийн хугацаа дууссан. Дахин оролдоно уу.',
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getColor().withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            _remainingTime.inMinutes < 2 ? Icons.timer : Icons.access_time,
            color: _getColor(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Төлбөрийн үлдсэн хугацаа',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getColor(),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatTime(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getColor(),
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _getTimeMessage(),
                      style: TextStyle(
                        color: _getColor(),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.orderId != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getColor().withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ID: ${widget.orderId!.substring(0, 8)}...',
                style: TextStyle(
                  fontSize: 10,
                  color: _getColor(),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getTimeMessage() {
    if (_remainingTime.inMinutes >= 5) {
      return 'Хэвээр байна';
    } else if (_remainingTime.inMinutes >= 2) {
      return 'Удахгүй дуусна';
    } else if (_remainingTime.inMinutes >= 1) {
      return 'Яаралтай!';
    } else {
      return 'Сүүлд!';
    }
  }
}
