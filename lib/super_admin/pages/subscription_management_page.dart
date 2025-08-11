import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SubscriptionManagementPage extends StatefulWidget {
  const SubscriptionManagementPage({super.key});

  @override
  State<SubscriptionManagementPage> createState() =>
      _SubscriptionManagementPageState();
}

class _SubscriptionManagementPageState
    extends State<SubscriptionManagementPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _subscriptionPayments = [];
  String _filterStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSubscriptionPayments();
  }

  Future<void> _loadSubscriptionPayments() async {
    try {
      setState(() {
        _isLoading = true;
      });

      List<Map<String, dynamic>> payments = [];

      // Get all stores to build a lookup map
      final storesSnapshot =
          await FirebaseFirestore.instance.collection('stores').get();

      Map<String, Map<String, dynamic>> storesMap = {};
      for (final storeDoc in storesSnapshot.docs) {
        storesMap[storeDoc.id] = {
          'id': storeDoc.id,
          ...storeDoc.data(),
        };
      }

      // Get all subscription payments from all stores
      for (final storeEntry in storesMap.entries) {
        final storeId = storeEntry.key;
        final storeData = storeEntry.value;

        try {
          final paymentsSnapshot = await FirebaseFirestore.instance
              .collection('store_subscriptions')
              .doc(storeId)
              .collection('payments')
              .orderBy('createdAt', descending: true)
              .get();

          for (final paymentDoc in paymentsSnapshot.docs) {
            final paymentData = paymentDoc.data();
            payments.add({
              'paymentId': paymentDoc.id,
              'storeId': storeId,
              'storeData': storeData,
              'paymentData': paymentData,
            });
          }
        } catch (e) {
          debugPrint('Error loading payments for store $storeId: $e');
          // Continue with other stores even if one fails
        }
      }

      // Sort by payment creation date (newest first)
      payments.sort((a, b) {
        final aDate = a['paymentData']['createdAt'] as Timestamp?;
        final bDate = b['paymentData']['createdAt'] as Timestamp?;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return bDate.compareTo(aDate);
      });

      setState(() {
        _subscriptionPayments = payments;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading subscription payments: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPayments {
    return _subscriptionPayments.where((payment) {
      final storeData = payment['storeData'] as Map<String, dynamic>;
      final paymentData = payment['paymentData'] as Map<String, dynamic>;

      // Filter by status
      if (_filterStatus != 'all') {
        final status = paymentData['status'] ?? 'pending';
        if (status != _filterStatus) return false;
      }

      // Filter by search query
      if (_searchQuery.isNotEmpty) {
        final storeName = (storeData['name'] ?? '').toString().toLowerCase();
        final orderId = (paymentData['orderId'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();

        if (!storeName.contains(query) && !orderId.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _updatePaymentStatus(
      String storeId, String paymentId, String newStatus) async {
    try {
      // Update payment status
      await FirebaseFirestore.instance
          .collection('store_subscriptions')
          .doc(storeId)
          .collection('payments')
          .doc(paymentId)
          .update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'verifiedBy': 'super_admin', // Track who verified
      });

      // Update store KYC and bank verification status based on payment verification
      String kycStatus;
      String bankVerificationStatus;

      if (newStatus == 'verified') {
        kycStatus = 'verified';
        bankVerificationStatus = 'verified';
      } else if (newStatus == 'rejected') {
        kycStatus = 'rejected';
        bankVerificationStatus = 'rejected';
      } else {
        kycStatus = 'pending';
        bankVerificationStatus = 'pending';
      }

      // Update store document with new verification statuses
      await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .update({
        'kycStatus': kycStatus,
        'bankVerificationStatus': bankVerificationStatus,
        'subscriptionPaymentStatus': newStatus,
        'lastVerificationUpdate': FieldValue.serverTimestamp(),
      });

      // Refresh the data
      await _loadSubscriptionPayments();

      if (mounted) {
        String statusText = newStatus == 'verified'
            ? 'баталгаажуулалт амжилттай'
            : newStatus == 'rejected'
                ? 'баталгаажуулалт амжилтгүй'
                : newStatus;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Төлбөр болон KYC статус "$statusText" болж өөрчлөгдлөө'),
            backgroundColor:
                newStatus == 'verified' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Статус өөрчлөхөд алдаа гарлаа: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showKycPhotos(Map<String, dynamic> storeData) {
    final idCardFrontImage = storeData['idCardFrontImage'] as String?;
    final idCardBackImage = storeData['idCardBackImage'] as String?;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 600,
          height: 500,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'KYC Баримт бичгүүд - ${storeData['name']}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  children: [
                    // Front ID Card
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Иргэний үнэмлэх (Нүүр тал)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: idCardFrontImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: idCardFrontImage,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) =>
                                            const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            const Center(
                                          child: Icon(Icons.error,
                                              color: Colors.red),
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: Text(
                                        'Зураг байхгүй',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Back ID Card
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Иргэний үнэмлэх (Ар тал)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: idCardBackImage != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: idCardBackImage,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) =>
                                            const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            const Center(
                                          child: Icon(Icons.error,
                                              color: Colors.red),
                                        ),
                                      ),
                                    )
                                  : const Center(
                                      child: Text(
                                        'Зураг байхгүй',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Additional store info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Банкны мэдээлэл:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text('Банк: ${storeData['selectedBank'] ?? 'Тодорхойгүй'}'),
                    Text(
                        'Данс: ${storeData['bankAccountNumber'] ?? 'Тодорхойгүй'}'),
                    Text(
                        'Эзэмшигч: ${storeData['bankAccountHolderName'] ?? 'Тодорхойгүй'}'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey, width: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Сарын хураамжийн удирдлага',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Дэлгүүрүүдийн сарын хураамжийн төлбөрүүд, KYC баримт бичгүүд',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                // Filters
                Row(
                  children: [
                    // Search
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: InputDecoration(
                          hintText:
                              'Дэлгүүрийн нэр эсвэл захиалгын дугаарaar хайх...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Status filter
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _filterStatus,
                          onChanged: (value) {
                            setState(() {
                              _filterStatus = value ?? 'all';
                            });
                          },
                          items: const [
                            DropdownMenuItem(
                                value: 'all', child: Text('Бүх статус')),
                            DropdownMenuItem(
                                value: 'pending', child: Text('Хүлээгдэж буй')),
                            DropdownMenuItem(
                                value: 'verified', child: Text('Баталгаажсан')),
                            DropdownMenuItem(
                                value: 'rejected', child: Text('Татгалзсан')),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Refresh button
                    ElevatedButton.icon(
                      onPressed: _loadSubscriptionPayments,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Шинэчлэх'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPayments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.payment_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Сарын хураамжийн төлбөр байхгүй байна',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: _filteredPayments.length,
                        itemBuilder: (context, index) {
                          final payment = _filteredPayments[index];
                          final storeData =
                              payment['storeData'] as Map<String, dynamic>;
                          final paymentData =
                              payment['paymentData'] as Map<String, dynamic>;

                          final createdAt =
                              paymentData['createdAt'] as Timestamp?;
                          final amount =
                              paymentData['amount']?.toDouble() ?? 0.0;
                          final status = paymentData['status'] ?? 'pending';

                          Color statusColor;
                          String statusText;
                          switch (status) {
                            case 'verified':
                              statusColor = Colors.green;
                              statusText = 'Баталгаажсан';
                              break;
                            case 'rejected':
                              statusColor = Colors.red;
                              statusText = 'Татгалзсан';
                              break;
                            default:
                              statusColor = Colors.orange;
                              statusText = 'Хүлээгдэж буй';
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header row
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Store logo
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          child: storeData['logo'] != null
                                              ? CachedNetworkImage(
                                                  imageUrl: storeData['logo'],
                                                  fit: BoxFit.cover,
                                                  placeholder: (context, url) =>
                                                      const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                  errorWidget:
                                                      (context, url, error) =>
                                                          const Icon(
                                                    Icons.store,
                                                    color: Colors.grey,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.store,
                                                  color: Colors.grey,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Store info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              storeData['name'] ??
                                                  'Тодорхойгүй дэлгүүр',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Захиалгын дугаар: ${paymentData['orderId'] ?? 'Тодорхойгүй'}',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Дүн: ${NumberFormat('#,###').format(amount)} ₮',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Status and actions
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withValues(
                                                  alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                  color: statusColor),
                                            ),
                                            child: Text(
                                              statusText,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            createdAt != null
                                                ? DateFormat('yyyy/MM/dd HH:mm')
                                                    .format(createdAt.toDate())
                                                : 'Тодорхойгүй огноо',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Bank info
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.account_balance,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Банк: ${storeData['selectedBank'] ?? 'Тодорхойгүй'}',
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                              Text(
                                                'Данс: ${storeData['bankAccountNumber'] ?? 'Тодорхойгүй'}',
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                              Text(
                                                'Эзэмшигч: ${storeData['bankAccountHolderName'] ?? 'Тодорхойгүй'}',
                                                style: const TextStyle(
                                                    fontSize: 14),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // Action buttons
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            _showKycPhotos(storeData),
                                        icon: const Icon(Icons.photo_library),
                                        label: const Text('KYC зургууд'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      if (status == 'pending') ...[
                                        ElevatedButton.icon(
                                          onPressed: () => _updatePaymentStatus(
                                            payment['storeId'],
                                            payment['paymentId'],
                                            'verified',
                                          ),
                                          icon: const Icon(Icons.check),
                                          label: const Text('Зөвшөөрөх'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () => _updatePaymentStatus(
                                            payment['storeId'],
                                            payment['paymentId'],
                                            'rejected',
                                          ),
                                          icon: const Icon(Icons.close),
                                          label: const Text('Татгалзах'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
