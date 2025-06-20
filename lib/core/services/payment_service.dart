import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

class PaymentService {
  static final _functions = FirebaseFunctions.instance;

  static Future<void> payWithCard(
      {required int amountMinor, required String currency}) async {
    final orderId = DateTime.now().millisecondsSinceEpoch.toString();
    final callable = _functions.httpsCallable('createPaymentIntent');
    final result = await callable.call(<String, dynamic>{
      'amount': amountMinor,
      'currency': currency,
      'orderId': orderId,
    });
    final clientSecret = result.data['clientSecret'];

    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'Shoppy',
        style: ThemeMode.light,
      ),
    );

    await Stripe.instance.presentPaymentSheet();
  }
}
