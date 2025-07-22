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
          // Error fetching user data
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
      // Error getting delivery info
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Дэлгүүрийн мэдээлэл олдсонгүй')),
          );
        }
        return;
      }

      final storeData = storeDoc.data() as Map<String, dynamic>;
      final storeName = storeData['name'] as String? ?? 'Дэлгүүр';
      final storePhone = storeData['phone'] as String? ?? '';
      final storeEmail = storeData['email'] as String? ?? '';
      final storeFacebook = storeData['facebook'] as String? ?? '';
      final storeInstagram = storeData['instagram'] as String? ?? '';
      final storeDescription = storeData['description'] as String? ?? '';

      if (mounted) {
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
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Алдаа гарлаа: $e')),
        );
      }
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
            _buildOrderHeader(context, storeId, status, totalAmount, createdAt),
            _buildProgressTracker(context, status),
            _buildOrderItems(context, items),
            _buildContactStoreButton(context, storeId),
            _buildOrderSummary(context, data, totalAmount),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader(BuildContext context, String storeId, String status,
      double totalAmount, Timestamp createdAt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
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
              Text(
                'Захиалга #${widget.order.id.substring(0, 8).toUpperCase()}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _getStatusColor(status).withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(status),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Огноо: ${_formatDate(createdAt.toDate())}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Нийт дүн: ₮${totalAmount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTracker(BuildContext context, String status) {
    final steps = [
      TrackingStep(
        title: 'Захиалга өгөгдсөн',
        description: 'Захиалга амжилттай өгөгдлөө',
        icon: Icons.shopping_cart,
        status: _getStepStatus(status, 0),
      ),
      TrackingStep(
        title: 'Баталгаажсан',
        description: 'Захиалга баталгаажлаа',
        icon: Icons.check_circle,
        status: _getStepStatus(status, 1),
      ),
      TrackingStep(
        title: 'Илгээгдсэн',
        description: 'Захиалга илгээгдлээ',
        icon: Icons.local_shipping,
        status: _getStepStatus(status, 2),
      ),
      TrackingStep(
        title: 'Хүргэгдсэн',
        description: 'Захиалга хүргэгдлээ',
        icon: Icons.home,
        status: _getStepStatus(status, 3),
      ),
    ];

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Хүргэлтийн явц',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          ...steps.map((step) => _buildProgressStep(context, step)),
        ],
      ),
    );
  }

  Widget _buildProgressStep(BuildContext context, TrackingStep step) {
    Color stepColor;
    IconData stepIcon;

    switch (step.status) {
      case StepStatus.completed:
        stepColor = Colors.green;
        stepIcon = Icons.check_circle;
        break;
      case StepStatus.current:
        stepColor = Colors.blue;
        stepIcon = Icons.radio_button_checked;
        break;
      case StepStatus.pending:
        stepColor = Colors.grey;
        stepIcon = Icons.radio_button_unchecked;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: stepColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              stepIcon,
              color: stepColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: step.status == StepStatus.pending
                        ? Colors.grey.shade600
                        : Colors.black,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItems(
      BuildContext context, List<Map<String, dynamic>> items) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Захиалгын бараанууд',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => _buildOrderItem(context, item)),
        ],
      ),
    );
  }

  Widget _buildOrderItem(BuildContext context, Map<String, dynamic> item) {
    final name = item['name'] as String? ?? 'Unknown Product';
    final price = TypeUtils.safeCastDouble(item['price'], defaultValue: 0.0);
    final quantity = item['quantity'] as int? ?? 1;
    final imageUrl = item['imageUrl'] as String? ?? '';
    final variant = item['variant'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image, color: Colors.grey),
                    ),
                  )
                : Container(
                    width: 60,
                    height: 60,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
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
                Text(
                  'Тоо: $quantity',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₮${(price * quantity).toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactStoreButton(BuildContext context, String storeId) {
    return Container(
      margin: const EdgeInsets.all(20),
      child: ElevatedButton.icon(
        onPressed: () => _showContactStoreDialog(storeId),
        icon: const Icon(Icons.store),
        label: const Text('Дэлгүүртэй холбогдох'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderSummary(
      BuildContext context, Map<String, dynamic> data, double totalAmount) {
    // Get delivery information asynchronously
    return FutureBuilder<Map<String, String>>(
      future: _getDeliveryInfo(data),
      builder: (context, snapshot) {
        final deliveryInfo = snapshot.data ?? {};
        final recipientName = deliveryInfo['name'] ?? 'Хэрэглэгч';
        final fullAddress = deliveryInfo['address'] ?? 'Хаяг байхгүй';
        final phone = deliveryInfo['phone'] ?? '';

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
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

              // Payment method
              _buildDetailRow(
                'Төлбөрийн хэлбэр',
                _getPaymentMethodDisplay(data['paymentMethod'] ?? 'card'),
              ),
              const SizedBox(height: 12),

              // Delivery address
              Column(
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
      },
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return Colors.orange;
      case 'confirmed':
      case 'paid':
        return Colors.blue;
      case 'processing':
        return Colors.purple;
      case 'shipped':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
      case 'cancelled':
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return 'Өгөгдсөн';
      case 'confirmed':
        return 'Баталгаажсан';
      case 'paid':
        return 'Төлбөр хийгдсэн';
      case 'processing':
        return 'Боловсруулж байна';
      case 'shipped':
        return 'Илгээгдсэн';
      case 'delivered':
        return 'Хүргэгдсэн';
      case 'cancelled':
      case 'canceled':
        return 'Цуцлагдсан';
      default:
        return 'Өгөгдсөн';
    }
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
