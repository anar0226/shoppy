import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:avii/core/utils/type_utils.dart';

class OrderTrackingPage extends StatefulWidget {
  final QueryDocumentSnapshot order;

  const OrderTrackingPage({super.key, required this.order});

  @override
  State<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingPage> {
  // Fetch actual user data and delivery information
  Future<Map<String, String>> _getDeliveryInfo(
      Map<String, dynamic> orderData) async {
    try {
      final userId = orderData['userId'] as String?;
      final deliveryAddress =
          orderData['deliveryAddress'] as Map<String, dynamic>? ?? {};
      final shippingAddress = orderData['shippingAddress'] as String? ?? '';

      String userName = 'Хэрэглэгч';
      String userPhone = '';

      // Try to get user information from Firestore
      if (userId != null && userId.isNotEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data() as Map<String, dynamic>;
            userName = userData['displayName'] as String? ??
                userData['firstName'] as String? ??
                userData['name'] as String? ??
                'Хэрэглэгч';
            userPhone = userData['phoneNumber'] as String? ??
                userData['phone'] as String? ??
                '';
          }
        } catch (e) {
          print('Error fetching user data: $e');
        }
      }

      // Get delivery address information
      String finalAddress = 'Хаяг байхгүй';
      String phone = userPhone;

      if (deliveryAddress.isNotEmpty) {
        // Try different possible field names for address
        finalAddress = deliveryAddress['fullAddress'] as String? ??
            deliveryAddress['address'] as String? ??
            deliveryAddress['line1'] as String? ??
            shippingAddress;

        // Try different possible field names for phone
        phone = deliveryAddress['phone'] as String? ??
            deliveryAddress['contactPhone'] as String? ??
            userPhone;

        // If we have firstName and lastName, use them instead
        final firstName = deliveryAddress['firstName'] as String? ?? '';
        final lastName = deliveryAddress['lastName'] as String? ?? '';
        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          userName = '$firstName $lastName'.trim();
        }
      } else if (shippingAddress.isNotEmpty) {
        finalAddress = shippingAddress;
      }

      return {
        'name': userName,
        'address': finalAddress,
        'phone': phone,
      };
    } catch (e) {
      print('Error getting delivery info: $e');
      return {
        'name': 'Хэрэглэгч',
        'address': 'Хаяг байхгүй',
        'phone': '',
      };
    }
  }

  // Show store contact information popup
  void _showContactStoreDialog(String storeId) async {
    try {
      final storeDoc = await FirebaseFirestore.instance
          .collection('stores')
          .doc(storeId)
          .get();

      if (!storeDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Дэлгүүрийн мэдээлэл олдсонгүй')),
        );
        return;
      }

      final storeData = storeDoc.data() as Map<String, dynamic>;
      final storeName = storeData['name'] as String? ?? 'Дэлгүүр';
      final storePhone = storeData['phone'] as String? ?? '';
      final storeEmail = storeData['email'] as String? ?? '';
      final storeFacebook = storeData['facebook'] as String? ?? '';
      final storeInstagram = storeData['instagram'] as String? ?? '';
      final storeDescription = storeData['description'] as String? ?? '';

      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(Icons.store, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    storeName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (storeDescription.isNotEmpty) ...[
                    Text(
                      storeDescription,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'Холбоо барих',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (storePhone.isNotEmpty)
                    _buildContactItem(
                      Icons.phone,
                      'Утас',
                      storePhone,
                      () => _launchPhone(storePhone),
                    ),
                  if (storeEmail.isNotEmpty)
                    _buildContactItem(
                      Icons.email,
                      'И-мэйл',
                      storeEmail,
                      () => _launchEmail(storeEmail),
                    ),
                  if (storeFacebook.isNotEmpty)
                    _buildContactItem(
                      Icons.facebook,
                      'Facebook',
                      storeFacebook,
                      () => _launchUrl(storeFacebook),
                    ),
                  if (storeInstagram.isNotEmpty)
                    _buildContactItem(
                      Icons.camera_alt,
                      'Instagram',
                      storeInstagram,
                      () => _launchUrl(storeInstagram),
                    ),
                  if (storePhone.isEmpty &&
                      storeEmail.isEmpty &&
                      storeFacebook.isEmpty &&
                      storeInstagram.isEmpty)
                    Text(
                      'Холбогдох мэдээлэл байхгүй байна',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Хаах'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Алдаа гарлаа: $e')),
      );
    }
  }

  Widget _buildContactItem(
      IconData icon, String title, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: Colors.blue.shade600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 12,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _launchPhone(String phone) {
    // This would launch phone dialer in a real app
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Утасны дугаар: $phone')),
    );
  }

  void _launchEmail(String email) {
    // This would launch email client in a real app
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('И-мэйл: $email')),
    );
  }

  void _launchUrl(String url) {
    // This would launch browser in a real app
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Холбоос: $url')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use real-time stream to get live updates when admin changes status
    return StreamBuilder<DocumentSnapshot>(
      stream: widget.order.reference.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Захиалгын статус',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Захиалгын статус',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            body: const Center(
              child: Text(
                'Захиалга олдсонгүй',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final storeId = TypeUtils.extractStoreId(data['storeId']);
        final status = data['status'] as String? ?? 'placed';
        final totalAmount =
            TypeUtils.safeCastDouble(data['total'], defaultValue: 0.0);
        final createdAt = (data['createdAt'] ?? Timestamp.now()) as Timestamp;
        final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

        return _buildOrderTrackingContent(
            context, storeId, status, totalAmount, createdAt, items, data);
      },
    );
  }

  Widget _buildOrderTrackingContent(
      BuildContext context,
      String storeId,
      String status,
      double totalAmount,
      Timestamp createdAt,
      List<Map<String, dynamic>> items,
      Map<String, dynamic> data) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Захиалгын статус',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Order Header
            _buildOrderHeader(storeId, items, totalAmount, createdAt),

            const SizedBox(height: 24),

            // Progress Tracker
            _buildProgressTracker(status, data),

            const SizedBox(height: 32),

            // Order Items
            _buildOrderItems(items),

            const SizedBox(height: 16),

            // Contact Store Button
            _buildContactStoreButton(storeId),

            const SizedBox(height: 24),

            // Order Summary
            _buildOrderSummary(totalAmount, data),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader(String storeId, List<Map<String, dynamic>> items,
      double totalAmount, Timestamp createdAt) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              const Icon(Icons.receipt_long, color: Colors.blue, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Захиалгын дугаар',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '#${widget.order.id.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Нийт дүн',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '₮${totalAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Захиалсан огноо',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDate(createdAt.toDate()),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTracker(String status, Map<String, dynamic> data) {
    final steps = [
      TrackingStep(
        title: 'Захиалга баталгаажлаа',
        description: 'Бид таны захиалгыг хүлээн авлаа',
        icon: Icons.check_circle,
        status: _getStepStatus(status, 0),
      ),
      TrackingStep(
        title: 'Xүргэxэд бэлдэж байна',
        description: 'Таны захиалгыг xүргэхэд бэлтгэж байна',
        icon: Icons.inventory_2,
        status: _getStepStatus(status, 1),
      ),
      TrackingStep(
        title: 'Бүтээгдэхүүн илгээгдсэн',
        description: 'Таны захиалга замдаа зарлаа',
        icon: Icons.local_shipping,
        status: _getStepStatus(status, 2),
      ),
      TrackingStep(
        title: 'Бүтээгдэхүүн хүргэгдсэн',
        description: 'Таны захиалга амжилттай хүргэгдсэн',
        icon: Icons.home,
        status: _getStepStatus(status, 3),
      ),
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Захиалгын явц',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              // Show last updated time if available
              if (data['updatedAt'] != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.3),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'актив',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Шинэчлэгдсэн: ${_formatUpdateTime(data['updatedAt'] as Timestamp?)}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Progress Steps
          for (int i = 0; i < steps.length; i++) ...[
            _buildProgressStep(steps[i], i == steps.length - 1),
            if (i < steps.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressStep(TrackingStep step, bool isLast) {
    Color stepColor = step.status == StepStatus.completed
        ? Colors.green
        : step.status == StepStatus.current
            ? Colors.blue
            : Colors.grey.shade300;

    Color textColor =
        step.status == StepStatus.completed || step.status == StepStatus.current
            ? Colors.black
            : Colors.grey.shade600;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step indicator
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: stepColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                step.status == StepStatus.completed ? Icons.check : step.icon,
                color: step.status == StepStatus.pending
                    ? Colors.grey.shade600
                    : Colors.white,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(vertical: 8),
              ),
          ],
        ),

        const SizedBox(width: 16),

        // Step content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                step.description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              if (step.status == StepStatus.current)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Одоогийн төлөв',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItems(List<Map<String, dynamic>> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Захиалсан бараа',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Colors.grey.shade200,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return _buildOrderItem(item);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContactStoreButton(String storeId) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showContactStoreDialog(storeId),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 2,
          ),
          icon: const Icon(Icons.contact_support, size: 20),
          label: const Text(
            'Дэлгүүртэй холбогдох',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    final productName = item['name'] ?? 'Бүтээгдэхүүн';
    final price = TypeUtils.safeCastDouble(item['price'], defaultValue: 0.0);
    final quantity = TypeUtils.safeCastInt(item['quantity'], defaultValue: 1);
    final variant = item['variant'] ?? '';
    final imageUrl = item['imageUrl'] ?? '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Product image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade100,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.inventory_2,
                          color: Colors.grey,
                          size: 24,
                        );
                      },
                    )
                  : const Icon(
                      Icons.inventory_2,
                      color: Colors.grey,
                      size: 24,
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (variant.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    variant,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '₮${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '× $quantity',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(double totalAmount, Map<String, dynamic> data) {
    final paymentMethod = data['paymentMethod'] as String? ?? 'Карт';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const Text(
            'Захиалгын дэлгэрэнгүй',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 16),

          // Payment Method
          _buildDetailRow(
              'Төлбөрийн хэрэгсэл', _getPaymentMethodDisplay(paymentMethod)),

          const SizedBox(height: 12),

          // Delivery Address Section
          FutureBuilder<Map<String, String>>(
            future: _getDeliveryInfo(data),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Хүргэлтийн хаяг',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 8),
                    CircularProgressIndicator(),
                  ],
                );
              }

              final deliveryInfo = snapshot.data ?? {};
              final recipientName = deliveryInfo['name'] ?? 'Хэрэглэгч';
              final fullAddress = deliveryInfo['address'] ?? 'Хаяг байхгүй';
              final phone = deliveryInfo['phone'] ?? '';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Хүргэлтийн хаяг',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recipientName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fullAddress,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 16),

          Container(
            height: 1,
            color: Colors.grey.shade300,
          ),

          const SizedBox(height: 16),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Нийт дүн',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                '₮${totalAmount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }

  StepStatus _getStepStatus(String orderStatus, int stepIndex) {
    // Enhanced status mapping to match admin panel statuses
    Map<String, int> statusSteps = {
      'placed': 0, // Order placed
      'confirmed': 1, // Order confirmed
      'paid': 1, // Order paid (same as confirmed)
      'processing': 1, // Processing
      'shipped': 2, // Shipped
      'delivered': 3, // Delivered
      'cancelled': -1, // Cancelled
      'canceled': -1, // Alternative spelling
    };

    int currentStep = statusSteps[orderStatus.toLowerCase()] ?? 0;

    if (orderStatus.toLowerCase() == 'cancelled' ||
        orderStatus.toLowerCase() == 'canceled') {
      return StepStatus.pending; // Show all as pending if cancelled
    }

    if (stepIndex < currentStep) {
      return StepStatus.completed;
    } else if (stepIndex == currentStep) {
      return StepStatus.current;
    } else {
      return StepStatus.pending;
    }
  }

  String _getPaymentMethodDisplay(String paymentMethod) {
    switch (paymentMethod.toLowerCase()) {
      case 'qpay':
        return 'QPay';
      case 'card':
      case 'visa':
      case 'mastercard':
        return 'Карт';
      case 'cash':
        return 'Бэлэн мөнгө';
      default:
        return 'Карт';
    }
  }

  String _formatUpdateTime(Timestamp? timestamp) {
    if (timestamp == null) return '';

    final now = DateTime.now();
    final updateTime = timestamp.toDate();
    final difference = now.difference(updateTime);

    if (difference.inMinutes < 1) {
      return 'Одоо';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} мин өмнө';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} цаг өмнө';
    } else {
      return '${updateTime.day}/${updateTime.month} ${updateTime.hour}:${updateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      '1 сарын',
      '2 сарын',
      '3 сарын',
      '4 сарын',
      '5 сарын',
      '6 сарын',
      '7 сарын',
      '8 сарын',
      '9 сарын',
      '10 сарын',
      '11 сарын',
      '12 сарын'
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class TrackingStep {
  final String title;
  final String description;
  final IconData icon;
  final StepStatus status;

  TrackingStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
  });
}

enum StepStatus {
  completed,
  current,
  pending,
}
