import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/checkout/models/checkout_item.dart';
import 'qpay_service.dart';

/// Payment service using QPay for processing payments in Mongolia
class PaymentService {
  static final _functions = FirebaseFunctions.instance;

  /// Complete payment flow with QPay order creation
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
      // Use QPay service for payment processing
      return await QPayService.processPayment(
        amount: amount,
        currency: currency,
        email: email,
        fullAddress: fullAddress,
        item: item,
        subtotal: subtotal,
        shippingCost: shippingCost,
        tax: tax,
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        error: 'Payment failed: ${e.toString()}',
      );
    }
  }

  /// Check payment status and complete order if paid
  static Future<bool> checkAndCompletePayment(String orderId) async {
    try {
      await QPayService.checkAndCompletePayment(orderId);
      return true;
    } catch (e) {
      print('Error completing payment: $e');
      return false;
    }
  }

  /// Cancel a pending payment
  static Future<bool> cancelPayment(String invoiceId) async {
    try {
      final qpay = QPayService();
      return await qpay.cancelPayment(invoiceId);
    } catch (e) {
      print('Error canceling payment: $e');
      return false;
    }
  }

  /// Process refund through QPay
  static Future<QPayRefundResult> processRefund({
    required String paymentId,
    required double amount,
    String? reason,
  }) async {
    try {
      final qpay = QPayService();
      return await qpay.processRefund(
        paymentId: paymentId,
        amount: amount,
        reason: reason,
      );
    } catch (e) {
      return QPayRefundResult(
        success: false,
        error: 'Refund failed: ${e.toString()}',
      );
    }
  }

  /// Get payment history from QPay
  static Future<List<QPayPaymentResult>> getPaymentHistory({
    String objectType = 'MERCHANT',
    required String objectId,
    int pageNumber = 1,
    int pageLimit = 50,
  }) async {
    try {
      final qpay = QPayService();
      return await qpay.getPaymentList(
        objectType: objectType,
        objectId: objectId,
        pageNumber: pageNumber,
        pageLimit: pageLimit,
      );
    } catch (e) {
      print('Error getting payment history: $e');
      return [];
    }
  }

  /// Convert MNT to other currencies (approximate)
  static double convertFromMNT(double amountMNT, String targetCurrency) {
    switch (targetCurrency.toUpperCase()) {
      case 'USD':
        return amountMNT / 3000; // Approximate conversion rate
      case 'EUR':
        return amountMNT / 3300; // Approximate conversion rate
      case 'CNY':
        return amountMNT / 430; // Approximate conversion rate
      case 'MNT':
      default:
        return amountMNT;
    }
  }

  /// Convert other currencies to MNT (approximate)
  static double convertToMNT(double amount, String fromCurrency) {
    switch (fromCurrency.toUpperCase()) {
      case 'USD':
        return amount * 3000; // Approximate conversion rate
      case 'EUR':
        return amount * 3300; // Approximate conversion rate
      case 'CNY':
        return amount * 430; // Approximate conversion rate
      case 'MNT':
      default:
        return amount;
    }
  }

  /// Create order via Cloud Function (for direct order creation)
  static Future<String> createOrder({
    required List<CheckoutItem> items,
    required double total,
    required double subtotal,
    required double tax,
    required double shipping,
    required String shippingAddress,
    required String email,
    String? paymentId,
  }) async {
    final callable = _functions.httpsCallable('createOrder');

    // Convert items to serializable format
    final itemsData = items
        .map((item) => {
              'name': item.name,
              'price': item.price,
              'quantity': 1, // Default quantity
              'variant': item.variant,
              'imageUrl': item.imageUrl,
              // Note: storeId and category need to be passed separately or added to CheckoutItem model
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
      if (paymentId != null) 'paymentId': paymentId,
    });

    return result.data['orderId'];
  }
}
