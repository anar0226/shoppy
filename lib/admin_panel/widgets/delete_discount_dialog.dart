import 'package:flutter/material.dart';

class DeleteDiscountDialog extends StatelessWidget {
  final String discountName;
  final String discountCode;
  final VoidCallback onConfirm;

  const DeleteDiscountDialog({
    super.key,
    required this.discountName,
    required this.discountCode,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Discount'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'Are you sure you want to delete "$discountName" (Code: $discountCode)?'),
          const SizedBox(height: 8),
          const Text(
            'This action cannot be undone and will permanently remove this discount code.',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
