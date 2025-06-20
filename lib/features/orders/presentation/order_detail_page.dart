import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrderDetailPage extends StatelessWidget {
  final DocumentSnapshot orderDoc;
  const OrderDetailPage({super.key, required this.orderDoc});

  @override
  Widget build(BuildContext context) {
    final data = orderDoc.data() as Map<String, dynamic>;
    final items = List<Map<String, dynamic>>.from(data['items'] ?? []);
    final item = items.isNotEmpty ? items.first : null;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Review your order'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1 of ${items.length} products',
                  style: const TextStyle(fontSize: 16, color: Colors.black54)),
              const SizedBox(height: 12),
              if (item != null) _productRow(item),
              const SizedBox(height: 24),
              const Text('Tell us about the product',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              _ReviewForm(productId: item?['productId'] ?? ''),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productRow(Map item) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            item['imageUrl'] ?? '',
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item['name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if ((item['variant'] ?? '').isNotEmpty)
                Text(item['variant'],
                    style: const TextStyle(color: Colors.black54)),
            ],
          ),
        )
      ],
    );
  }
}

class _ReviewForm extends StatefulWidget {
  final String productId;
  const _ReviewForm({required this.productId});
  @override
  State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  int _rating = 0;
  final _controller = TextEditingController();
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            final idx = i + 1;
            return IconButton(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              onPressed: () => setState(() => _rating = idx),
              icon: Icon(idx <= _rating ? Icons.star : Icons.star_border,
                  color: Colors.black, size: 32),
            );
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'What did you like or dislike?',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
              'Reviewing as ${FirebaseAuth.instance.currentUser?.displayName ?? 'You'}',
              style: const TextStyle(color: Colors.black54)),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Text('Submit'),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _submitting = true);
    await FirebaseFirestore.instance
        .collection('products')
        .doc(widget.productId)
        .collection('reviews')
        .add({
      'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
      'rating': _rating,
      'comment': _controller.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thank you for your review!')));
      Navigator.pop(context);
    }
  }
}
