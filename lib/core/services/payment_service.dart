import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/checkout/models/checkout_item.dart';

class PaymentService {
  static final _functions = FirebaseFunctions.instance;

  /// Complete payment flow with order creation
  static Future<PaymentResult> processPayment({
    required double amount,
    required String currency,
    required String email,
    required String fullAddress,
    required CheckoutItem item,
    required double subtotal,
    required double shippingCost,
    required double tax,
  }) async {
    try {
      // Step 1: Create order first
      final orderId = await _createOrder(
        items: [item],
        total: amount,
        subtotal: subtotal,
        tax: tax,
        shipping: shippingCost,
        shippingAddress: fullAddress,
        email: email,
      );

      // Step 2: Create payment intent
      final paymentIntentResult = await _createPaymentIntent(
        amountMinor: (amount * 100).round(), // Convert to cents
        currency: currency,
        orderId: orderId,
        email: email,
      );

      // Step 3: Initialize and present payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentIntentResult.clientSecret,
          merchantDisplayName: 'Shoppy',
          style: ThemeMode.light,
          billingDetails: BillingDetails(
            email: email,
            address: Address(
              line1: fullAddress,
              line2: null,
              city: 'Unknown', // Add required city field
              state: null,
              postalCode: null,
              country: 'US', // You might want to extract this from address
            ),
          ),
        ),
      );

      // Step 4: Present payment sheet
      await Stripe.instance.presentPaymentSheet();

      // Step 5: Return success result
      return PaymentResult(
        success: true,
        orderId: orderId,
        paymentIntentId: paymentIntentResult.paymentIntentId,
      );
    } on StripeException catch (e) {
      return PaymentResult(
        success: false,
        error: _getStripeErrorMessage(e),
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        error: 'Payment failed: ${e.toString()}',
      );
    }
  }

  /// Create payment intent via Cloud Function
  static Future<PaymentIntentResult> _createPaymentIntent({
    required int amountMinor,
    required String currency,
    required String orderId,
    required String email,
  }) async {
    final callable = _functions.httpsCallable('createPaymentIntent');
    final result = await callable.call(<String, dynamic>{
      'amount': amountMinor,
      'currency': currency,
      'orderId': orderId,
      'email': email,
    });

    return PaymentIntentResult(
      clientSecret: result.data['clientSecret'],
      paymentIntentId: result.data['paymentIntentId'],
    );
  }

  /// Create order via Cloud Function
  static Future<String> _createOrder({
    required List<CheckoutItem> items,
    required double total,
    required double subtotal,
    required double tax,
    required double shipping,
    required String shippingAddress,
    required String email,
  }) async {
    final callable = _functions.httpsCallable('createOrder');

    // Convert items to serializable format
    final itemsData = items
        .map((item) => {
              'name': item.name,
              'price': item.price,
              'quantity':
                  1, // Default quantity since CheckoutItem doesn't have this field
              'variant': item.variant,
              'imageUrl': item.imageUrl,
              'productId': DateTime.now()
                  .millisecondsSinceEpoch
                  .toString(), // Generate ID since CheckoutItem doesn't have id
            })
        .toList();

    final result = await callable.call(<String, dynamic>{
      'items': itemsData,
      'total': total,
      'subtotal': subtotal,
      'tax': tax,
      'shipping': shipping,
      'shippingAddress': shippingAddress,
      'email': email,
    });

    return result.data['orderId'];
  }

  /// Convert Stripe errors to user-friendly messages
  static String _getStripeErrorMessage(StripeException e) {
    switch (e.error.code) {
      case FailureCode.Canceled:
        return 'Payment was cancelled';
      case FailureCode.Failed:
        return 'Payment failed. Please try again.';
      case FailureCode.Timeout:
        return 'Payment timed out. Please try again.';
      default:
        return 'Payment failed: ${e.error.localizedMessage ?? 'Unknown error'}';
    }
  }

  /// Legacy method for backwards compatibility
  @deprecated
  static Future<void> payWithCard(
      {required int amountMinor, required String currency}) async {
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();
    final result = await _createPaymentIntent(
      amountMinor: amountMinor,
      currency: currency,
      orderId: orderId,
      email: FirebaseAuth.instance.currentUser?.email ?? '',
    );

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: result.clientSecret,
        merchantDisplayName: 'Shoppy',
        style: ThemeMode.light,
      ),
    );

    await Stripe.instance.presentPaymentSheet();
  }
}

/// Result of payment processing
class PaymentResult {
  final bool success;
  final String? orderId;
  final String? paymentIntentId;
  final String? error;

  PaymentResult({
    required this.success,
    this.orderId,
    this.paymentIntentId,
    this.error,
  });
}

/// Result of payment intent creation
class PaymentIntentResult {
  final String clientSecret;
  final String paymentIntentId;

  PaymentIntentResult({
    required this.clientSecret,
    required this.paymentIntentId,
  });
}
