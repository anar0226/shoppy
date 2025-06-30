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
  @override
  Widget build(BuildContext context) {
    final data = widget.order.data() as Map<String, dynamic>;
    final storeId = data['storeId'] as String? ?? '';
    final status = data['status'] as String? ?? 'placed';
    final totalAmount =
        TypeUtils.safeCastDouble(data['total'], defaultValue: 0.0);
    final createdAt = (data['createdAt'] ?? Timestamp.now()) as Timestamp;
    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);

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
            _buildProgressTracker(status),

            const SizedBox(height: 32),

            // Order Items
            _buildOrderItems(items),

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

  Widget _buildProgressTracker(String status) {
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
          const Text(
            'Захиалгын явц',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
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
                    'Одоогийн алхам',
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
    final deliveryAddress =
        data['deliveryAddress'] as Map<String, dynamic>? ?? {};
    final recipientName = deliveryAddress['recipientName'] as String? ??
        deliveryAddress['contactName'] as String? ??
        'Хэрэглэгч';
    final fullAddress = deliveryAddress['fullAddress'] as String? ??
        deliveryAddress['address'] as String? ??
        'Хаяг байхгүй';
    final phone = deliveryAddress['phone'] as String? ??
        deliveryAddress['contactPhone'] as String? ??
        '';

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

          // Delivery Address
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
    // Map orderStatus to step completion
    Map<String, int> statusSteps = {
      'placed': 0, // Order placed
      'confirmed': 1, // Order confirmed
      'processing': 1, // Processing
      'shipped': 2, // Shipped
      'delivered': 3, // Delivered
      'cancelled': -1, // Cancelled
    };

    int currentStep = statusSteps[orderStatus] ?? 0;

    if (orderStatus == 'cancelled') {
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
