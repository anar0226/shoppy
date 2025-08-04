import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';
import '../../features/settings/themes/app_themes.dart';

class PaymentVerificationPage extends StatefulWidget {
  const PaymentVerificationPage({super.key});

  @override
  State<PaymentVerificationPage> createState() =>
      _PaymentVerificationPageState();
}

class _PaymentVerificationPageState extends State<PaymentVerificationPage> {
  final _orderIdController = TextEditingController();
  final _storeIdController = TextEditingController();
  final _amountController = TextEditingController();
  final _transactionRefController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  String? _success;

  @override
  void dispose() {
    _orderIdController.dispose();
    _storeIdController.dispose();
    _amountController.dispose();
    _transactionRefController.dispose();
    super.dispose();
  }

  Future<void> _verifyPayment() async {
    if (_orderIdController.text.isEmpty ||
        _storeIdController.text.isEmpty ||
        _amountController.text.isEmpty) {
      setState(() {
        _error = 'Бүх талбарыг бөглөнө үү';
        _success = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _success = null;
    });

    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('manualPaymentVerification');

      final result = await callable.call({
        'orderId': _orderIdController.text.trim(),
        'storeId': _storeIdController.text.trim(),
        'amount': double.parse(_amountController.text.trim()),
        'transactionReference': _transactionRefController.text.trim(),
      });

      final data = result.data as Map<String, dynamic>;

      if (data['success'] == true) {
        setState(() {
          _success = 'Төлбөр амжилттай баталгаажлаа';
          _error = null;
        });

        // Clear form
        _orderIdController.clear();
        _storeIdController.clear();
        _amountController.clear();
        _transactionRefController.clear();
      } else {
        setState(() {
          _error = data['message'] ?? 'Төлбөр баталгаажаагүй';
          _success = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Алдаа гарлаа: $e';
        _success = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Төлбөр баталгаажуулалт'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4285F4)
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.verified_user,
                                        color: Color(0xFF4285F4),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Төлбөр баталгаажуулалт',
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Банкны шилжүүлгэний төлбөрийг гараар баталгаажуулах',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),

                                // Form fields
                                TextFormField(
                                  controller: _orderIdController,
                                  decoration: const InputDecoration(
                                    labelText: 'Захиалгын дугаар',
                                    hintText:
                                        'Жишээ: SUB_store123_1234567890_abc123',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _storeIdController,
                                  decoration: const InputDecoration(
                                    labelText: 'Дэлгүүрийн ID',
                                    hintText: 'Дэлгүүрийн Firestore ID',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _amountController,
                                  decoration: const InputDecoration(
                                    labelText: 'Төлбөрийн дүн (₮)',
                                    hintText: '200',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _transactionRefController,
                                  decoration: const InputDecoration(
                                    labelText: 'Гүйлгээний дугаар (сонголттой)',
                                    hintText: 'Банкны гүйлгээний дугаар',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Error/Success messages
                                if (_error != null)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.red.shade200),
                                    ),
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),

                                if (_success != null)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.green.shade200),
                                    ),
                                    child: Text(
                                      _success!,
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),

                                if (_error != null || _success != null)
                                  const SizedBox(height: 24),

                                // Action button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isLoading ? null : _verifyPayment,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4285F4),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : const Text(
                                            'Төлбөр баталгаажуулах',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Information box
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border:
                                        Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.info_outline,
                                            color: Colors.blue.shade700,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Заавар',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.blue.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '• Захиалгын дугаарыг төлбөрийн хуудаснаас хуулж авна уу\n'
                                        '• Дэлгүүрийн ID-г Firestore-оос олно уу\n'
                                        '• Төлбөрийн дүнг банкны гүйлгээний дэлгэрэнгүй мэдээллээс шалгана уу\n'
                                        '• Гүйлгээний дугаарыг банкны аппликейшнаас хуулж авна уу',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.blue.shade800,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
