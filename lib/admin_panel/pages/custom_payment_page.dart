import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';
import '../../features/settings/themes/app_themes.dart';

class CustomPaymentPage extends StatefulWidget {
  final String storeId;
  final double amount;
  final String description;
  final String orderId;

  const CustomPaymentPage({
    super.key,
    required this.storeId,
    required this.amount,
    required this.description,
    required this.orderId,
  });

  @override
  State<CustomPaymentPage> createState() => _CustomPaymentPageState();
}

class _CustomPaymentPageState extends State<CustomPaymentPage> {
  bool _isLoading = false;
  String? _selectedBank;
  final List<String> _banks = ['Худалдаа хөгжлийн банк'];

  // Bank account details
  late final Map<String, Map<String, String>> _bankAccounts;

  @override
  void initState() {
    super.initState();
    _selectedBank = _banks[0]; // Default to TDB

    // Initialize bank accounts with correct details
    _bankAccounts = {
      'Худалдаа хөгжлийн банк': {
        'account': '436 022 735',
        'recipient': 'Анар Боргил',
        'qr_data': 'TDB:436022735:${widget.orderId}:${widget.amount.toInt()}',
      },
    };

    _savePaymentRecord();
  }

  Future<void> _savePaymentRecord() async {
    try {
      debugPrint('=== Saving payment record ===');
      debugPrint('Store ID: ${widget.storeId}');
      debugPrint('Order ID: ${widget.orderId}');
      debugPrint('Amount: ${widget.amount}');

      // Check if payment record already exists
      final existingDoc = await FirebaseFirestore.instance
          .collection('store_subscriptions')
          .doc(widget.storeId)
          .collection('payments')
          .doc(widget.orderId)
          .get();

      if (existingDoc.exists) {
        debugPrint('Payment record already exists, updating timestamp');
        await FirebaseFirestore.instance
            .collection('store_subscriptions')
            .doc(widget.storeId)
            .collection('payments')
            .doc(widget.orderId)
            .update({
          'lastAccessed': FieldValue.serverTimestamp(),
        });
      } else {
        debugPrint('Creating new payment record');
        await FirebaseFirestore.instance
            .collection('store_subscriptions')
            .doc(widget.storeId)
            .collection('payments')
            .doc(widget.orderId)
            .set({
          'orderId': widget.orderId,
          'amount': widget.amount,
          'description': widget.description,
          'status': 'pending',
          'paymentMethod': 'bank_transfer',
          'bankAccount': _bankAccounts[_selectedBank]!['account'],
          'recipient': _bankAccounts[_selectedBank]!['recipient'],
          'createdAt': FieldValue.serverTimestamp(),
          'userId': 'web_user', // You might want to get actual user ID
          'storeId': widget.storeId, // Add store ID for easier querying
        });
      }

      debugPrint('Payment record saved successfully');
    } catch (e, stackTrace) {
      debugPrint('=== Error saving payment record ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save payment record: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Хуулагдлаа: $text'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildInfoBox(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _copyToClipboard(value),
            icon: Icon(
              Icons.copy,
              color: Colors.grey.shade600,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedBankData = _bankAccounts[_selectedBank]!;
    final qrData = selectedBankData['qr_data']!;
    final isCompact = MediaQuery.of(context).size.width < 1100;

    if (isCompact) {
      // Compact: AppBar + stacked sections
      return Scaffold(
        backgroundColor: AppThemes.getBackgroundColor(context),
        appBar: AppBar(
          backgroundColor: const Color(0xFF4285F4),
          elevation: 0,
          title: const Text('Төлбөр',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // QR section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('QR код уншуулах',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Center(
                        child: QrImageView(
                          data: qrData,
                          version: QrVersions.auto,
                          size: 230,
                          backgroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Захиалгын дүн: ${widget.amount.toStringAsFixed(0)} ₮',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Bank transfer section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Дансаар шилжүүлэх',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Row(
                        children: _banks.map((bank) {
                          final isSelected = _selectedBank == bank;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedBank = bank),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF4285F4)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF4285F4)
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(bank,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey.shade700,
                                      fontWeight: FontWeight.w500,
                                    )),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoBox(
                          'Хүлээн авах данс', selectedBankData['account']!),
                      _buildInfoBox(
                          'Хүлээн авагч', selectedBankData['recipient']!),
                      _buildInfoBox('Захиалгын дүн',
                          '${widget.amount.toStringAsFixed(0)} ₮'),
                      _buildInfoBox('Гүйлгээний утга', widget.orderId),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Instructions
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(
                  'Төлбөр төлөгдсөний дараа таны дэлгүүр идэвхжих болно. Заавал ${widget.orderId} дугаарыг гүйлгээний утгад бичнэ үү.',
                  style: TextStyle(color: Colors.amber.shade800),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Буцах'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _checkPaymentStatus,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4285F4)),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Төлбөр шалгах'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Desktop/default layout
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Төлбөр'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 800),
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
                                // Header
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
                                        Icons.qr_code,
                                        color: Color(0xFF4285F4),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'ДАНС эсвэл QR код',
                                            style: TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Аль ч банкны аппликейшн ашиглан уншуулж болно.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                // Main content - two columns
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left column - QR Code
                                    Expanded(
                                      child: Column(
                                        children: [
                                          const Text(
                                            'QR код уншуулах',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: Colors.grey.shade300),
                                            ),
                                            child: QrImageView(
                                              data: qrData,
                                              version: QrVersions.auto,
                                              size: 200,
                                              backgroundColor: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Захиалгын дүн',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${widget.amount.toStringAsFixed(0)} ₮',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 32),
                                    // Right column - Bank Transfer
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Дансаар шилжүүлэх',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Row(
                                            children: _banks.map((bank) {
                                              final isSelected =
                                                  _selectedBank == bank;
                                              return Expanded(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    setState(() =>
                                                        _selectedBank = bank);
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      vertical: 12,
                                                      horizontal: 16,
                                                    ),
                                                    margin:
                                                        const EdgeInsets.only(
                                                            right: 8),
                                                    decoration: BoxDecoration(
                                                      color: isSelected
                                                          ? const Color(
                                                              0xFF4285F4)
                                                          : Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? const Color(
                                                                0xFF4285F4)
                                                            : Colors
                                                                .grey.shade300,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      bank,
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isSelected
                                                            ? Colors.white
                                                            : Colors
                                                                .grey.shade700,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                          const SizedBox(height: 20),
                                          _buildInfoBox('Хүлээн авах данс',
                                              selectedBankData['account']!),
                                          _buildInfoBox('Хүлээн авагч',
                                              selectedBankData['recipient']!),
                                          _buildInfoBox('Захиалгын дүн',
                                              '${widget.amount.toStringAsFixed(0)} ₮'),
                                          _buildInfoBox('Гүйлгээний утга',
                                              widget.orderId),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                // Information + actions remain
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.amber.shade200),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.info_outline,
                                              color: Colors.amber.shade700,
                                              size: 20),
                                          const SizedBox(width: 8),
                                          Text('Төлбөрийн заавар',
                                              style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                      Colors.amber.shade800)),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Төлбөр төлөгдсөний дараа таны дэлгүүр идэвхжих болно! Төлбөрийг дээрх дансанд шилжүүлэх ба захиалгын **${widget.orderId}** дугаарыг гүйлгээний утга дээр бичнэ үү. Мөн та QR кодыг уншуулж төлбөр төлөх боломжтой.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.amber.shade800,
                                          height: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          side: BorderSide(
                                              color: Colors.grey.shade300),
                                        ),
                                        child: const Text('Буцах',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500)),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _isLoading
                                            ? null
                                            : _checkPaymentStatus,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF4285F4),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    Colors.white,
                                                  ),
                                                ),
                                              )
                                            : const Text(
                                                'Төлбөр шалгах',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.white,
                                                ),
                                              ),
                                      ),
                                    ),
                                  ],
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

  Future<void> _checkPaymentStatus() async {
    setState(() => _isLoading = true);

    try {
      // Here you would implement the payment verification logic
      // This could involve:
      // 1. Checking your bank's API for recent transactions
      // 2. Checking a webhook from your bank
      // 3. Manual verification process

      // For now, we'll simulate a check
      await Future.delayed(const Duration(seconds: 2));

      // Update payment status in Firestore
      await FirebaseFirestore.instance
          .collection('store_subscriptions')
          .doc(widget.storeId)
          .collection('payments')
          .doc(widget.orderId)
          .update({
        'lastChecked': FieldValue.serverTimestamp(),
        'status': 'verifying',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Төлбөр шалгаж байна...'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Алдаа гарлаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
