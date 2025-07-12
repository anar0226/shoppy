import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/side_menu.dart';
import '../widgets/top_nav_bar.dart';
import '../auth/auth_service.dart';
import '../../features/settings/themes/app_themes.dart';
import '../../core/services/qpay_service.dart';
import '../../core/utils/popup_utils.dart';

class SubscriptionPage extends StatefulWidget {
  const SubscriptionPage({super.key});

  @override
  State<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends State<SubscriptionPage> {
  final QPayService _qpayService = QPayService();
  String? _currentStoreId;
  String? _storeName;
  bool _isLoading = true;
  bool _isProcessingPayment = false;

  // Subscription data
  DateTime? _lastPaymentDate;
  DateTime? _nextPaymentDate;
  bool _isSubscriptionActive = false;
  List<Map<String, dynamic>> _paymentHistory = [];

  // Monthly subscription fee
  static const double _monthlyFee = 5000.0;

  @override
  void initState() {
    super.initState();
    _loadStoreData();
  }

  Future<void> _loadStoreData() async {
    final ownerId = AuthService.instance.currentUser?.uid;
    if (ownerId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Get store information
      final storeSnapshot = await FirebaseFirestore.instance
          .collection('stores')
          .where('ownerId', isEqualTo: ownerId)
          .limit(1)
          .get();

      if (storeSnapshot.docs.isNotEmpty) {
        final storeData = storeSnapshot.docs.first.data();
        setState(() {
          _currentStoreId = storeSnapshot.docs.first.id;
          _storeName = storeData['name'] ?? 'Дэлгүүр';
        });

        await _loadSubscriptionData();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        PopupUtils.showError(
          context: context,
          message: 'Дэлгүүрийн мэдээлэл татахад алдаа гарлаа: $e',
        );
      }
    }
  }

  Future<void> _loadSubscriptionData() async {
    if (_currentStoreId == null) return;

    try {
      // Get subscription data
      final subDoc = await FirebaseFirestore.instance
          .collection('store_subscriptions')
          .doc(_currentStoreId)
          .get();

      if (subDoc.exists) {
        final data = subDoc.data()!;
        setState(() {
          _lastPaymentDate = (data['lastPaymentDate'] as Timestamp?)?.toDate();
          _nextPaymentDate = (data['nextPaymentDate'] as Timestamp?)?.toDate();
          _isSubscriptionActive = data['isActive'] ?? false;
        });
      } else {
        // Create initial subscription document
        await FirebaseFirestore.instance
            .collection('store_subscriptions')
            .doc(_currentStoreId)
            .set({
          'storeId': _currentStoreId,
          'storeName': _storeName,
          'isActive': false,
          'createdAt': FieldValue.serverTimestamp(),
          'monthlyFee': _monthlyFee,
        });
      }

      // Load payment history
      final historySnapshot = await FirebaseFirestore.instance
          .collection('store_subscriptions')
          .doc(_currentStoreId)
          .collection('payment_history')
          .orderBy('paymentDate', descending: true)
          .limit(10)
          .get();

      setState(() {
        _paymentHistory = historySnapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        PopupUtils.showError(
          context: context,
          message: 'Төлбөрийн мэдээлэл татахад алдаа гарлаа: $e',
        );
      }
    }
  }

  Future<void> _processMonthlyPayment() async {
    if (_currentStoreId == null || _isProcessingPayment) return;

    setState(() => _isProcessingPayment = true);

    try {
      // Generate unique payment ID
      final paymentId =
          '${_currentStoreId}_${DateTime.now().millisecondsSinceEpoch}';

      // Create QPay invoice
      final result = await _qpayService.createInvoice(
        orderId: paymentId,
        amount: _monthlyFee,
        description: 'Avii.mn сарын төлбөр - $_storeName',
        customerEmail: AuthService.instance.currentUser?.email ?? '',
      );

      if (result.success && result.invoice != null) {
        final invoice = result.invoice!;

        // Store pending payment
        await FirebaseFirestore.instance
            .collection('store_subscriptions')
            .doc(_currentStoreId)
            .collection('payment_history')
            .doc(paymentId)
            .set({
          'paymentId': paymentId,
          'amount': _monthlyFee,
          'status': 'pending',
          'qpayInvoiceId': invoice.qpayInvoiceId,
          'createdAt': FieldValue.serverTimestamp(),
          'description': 'Сарын төлбөр',
        });

        // Get payment URL
        String paymentUrl = invoice.bestPaymentUrl;
        if (paymentUrl.isEmpty && invoice.qrCode.isNotEmpty) {
          final encodedQR = Uri.encodeComponent(invoice.qrCode);
          paymentUrl = 'https://qpay.mn/q/?q=$encodedQR';
        }

        if (paymentUrl.isNotEmpty) {
          final launched = await launchUrl(
            Uri.parse(paymentUrl),
            mode: LaunchMode.externalApplication,
          );

          if (launched) {
            PopupUtils.showSuccess(
              context: context,
              message:
                  'QPay төлбөрийн хуудас нээгдлээ. Төлбөр хийсний дараа хуудас шинэчлэгдэх болно.',
            );

            // Start checking for payment completion
            _startPaymentStatusCheck(paymentId);
          } else {
            throw Exception('QPay хуудас нээхэд алдаа гарлаа');
          }
        } else {
          throw Exception('QPay төлбөрийн холбоос олдсонгүй');
        }
      } else {
        throw Exception(result.error ?? 'QPay захиалга үүсгэхэд алдаа гарлаа');
      }
    } catch (e) {
      if (mounted) {
        PopupUtils.showError(
          context: context,
          message: 'Төлбөр хийхэд алдаа гарлаа: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  void _startPaymentStatusCheck(String paymentId) {
    // Check payment status every 5 seconds for 2 minutes
    int checkCount = 0;
    final checkTimer =
        Stream.periodic(const Duration(seconds: 5), (count) => count);

    checkTimer.take(24).listen((count) async {
      checkCount = count;
      await _checkPaymentStatus(paymentId);
    });
  }

  Future<void> _checkPaymentStatus(String paymentId) async {
    try {
      final paymentDoc = await FirebaseFirestore.instance
          .collection('store_subscriptions')
          .doc(_currentStoreId)
          .collection('payment_history')
          .doc(paymentId)
          .get();

      if (paymentDoc.exists) {
        final data = paymentDoc.data()!;
        final status = data['status'];

        if (status == 'completed') {
          // Payment completed, refresh data
          await _loadSubscriptionData();

          if (mounted) {
            PopupUtils.showSuccess(
              context: context,
              message: 'Төлбөр амжилттай хийгдлээ!',
            );
          }
        }
      }
    } catch (e) {
      // Ignore errors during status check
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(selected: 'Захиалга'),
          Expanded(
            child: Column(
              children: [
                const TopNavBar(title: 'Захиалга'),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _currentStoreId == null
                          ? const Center(child: Text('Дэлгүүр олдсонгүй'))
                          : _buildSubscriptionContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Захиалгын удирдлага',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Сарын төлбөр: ₮${_monthlyFee.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
              _buildSubscriptionStatus(),
            ],
          ),
          const SizedBox(height: 32),

          // Subscription overview cards
          Row(
            children: [
              Expanded(child: _buildSubscriptionCard()),
              const SizedBox(width: 16),
              Expanded(child: _buildNextPaymentCard()),
            ],
          ),
          const SizedBox(height: 32),

          // Payment button
          _buildPaymentSection(),
          const SizedBox(height: 32),

          // Payment history
          _buildPaymentHistory(),
        ],
      ),
    );
  }

  Widget _buildSubscriptionStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color:
            _isSubscriptionActive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isSubscriptionActive
              ? Colors.green.shade200
              : Colors.red.shade200,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isSubscriptionActive ? Icons.check_circle : Icons.cancel,
            size: 16,
            color: _isSubscriptionActive ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            _isSubscriptionActive ? 'Идэвхтэй' : 'Идэвхгүй',
            style: TextStyle(
              color: _isSubscriptionActive ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.store,
                  color: Colors.blue.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Дэлгүүрийн захиалга',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      _storeName ?? 'Дэлгүүр',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_lastPaymentDate != null)
            Text(
              'Сүүлийн төлбөр: ${_formatDate(_lastPaymentDate!)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
        ],
      ),
    );
  }

  Widget _buildNextPaymentCard() {
    final isOverdue = _nextPaymentDate != null &&
        _nextPaymentDate!.isBefore(DateTime.now()) &&
        _isSubscriptionActive;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isOverdue ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isOverdue ? Icons.warning : Icons.schedule,
                  color:
                      isOverdue ? Colors.red.shade600 : Colors.green.shade600,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isOverdue ? 'Хоцорсон төлбөр' : 'Дараагийн төлбөр',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      _nextPaymentDate != null
                          ? _formatDate(_nextPaymentDate!)
                          : 'Тодорхойгүй',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                isOverdue ? Colors.red[600] : Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '₮${_monthlyFee.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isOverdue ? Colors.red : null,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сарын төлбөр хийх',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Дэлгүүрийн үйл ажиллагааг үргэлжлүүлэхийн тулд сарын төлбөрөө хийнэ үү.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Төлбөрийн дүн',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₮${_monthlyFee.toStringAsFixed(0)}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 200,
                child: ElevatedButton.icon(
                  onPressed:
                      _isProcessingPayment ? null : _processMonthlyPayment,
                  icon: _isProcessingPayment
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Image.asset(
                          'assets/images/logos/QPAY.png',
                          height: 20,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.payment);
                          },
                        ),
                  label: Text(_isProcessingPayment
                      ? 'Боловсруулж байна...'
                      : 'QPay-ээр төлөх'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistory() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Төлбөрийн түүх',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          if (_paymentHistory.isEmpty)
            const Center(
              child: Text(
                'Төлбөрийн түүх байхгүй',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _paymentHistory.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final payment = _paymentHistory[index];
                return _buildPaymentHistoryItem(payment);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryItem(Map<String, dynamic> payment) {
    final amount = payment['amount'] ?? 0.0;
    final status = payment['status'] ?? 'pending';
    final date = (payment['paymentDate'] as Timestamp?)?.toDate() ??
        (payment['createdAt'] as Timestamp?)?.toDate();
    final description = payment['description'] ?? 'Сарын төлбөр';

    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = 'Амжилттай';
        statusIcon = Icons.check_circle;
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'Хүлээгдэж байна';
        statusIcon = Icons.access_time;
        break;
      case 'failed':
        statusColor = Colors.red;
        statusText = 'Амжилтгүй';
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Тодорхойгүй';
        statusIcon = Icons.help_outline;
    }

    return ListTile(
      leading: Icon(statusIcon, color: statusColor),
      title: Text(description),
      subtitle: Text(date != null ? _formatDate(date) : 'Тодорхойгүй'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '₮${amount.toStringAsFixed(0)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}
