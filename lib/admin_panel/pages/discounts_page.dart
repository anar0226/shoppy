import 'package:flutter/material.dart';
import '../widgets/top_nav_bar.dart';
import '../widgets/side_menu.dart';
import '../widgets/add_discount_dialog.dart';
import '../widgets/edit_discount_dialog.dart';
import '../widgets/delete_discount_dialog.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_service.dart';
import '../../features/discounts/models/discount_model.dart';
import '../../features/discounts/services/discount_service.dart';
import '../../features/settings/themes/app_themes.dart';

class DiscountsPage extends StatefulWidget {
  const DiscountsPage({super.key});

  @override
  State<DiscountsPage> createState() => _DiscountsPageState();
}

class _DiscountsPageState extends State<DiscountsPage> {
  String? _storeId;
  bool _storeLoaded = false;
  final _discountService = DiscountService();

  @override
  void initState() {
    super.initState();
    _loadStoreId();
  }

  Future<void> _loadStoreId() async {
    final ownerId = AuthService.instance.currentUser?.uid;
    if (ownerId == null) {
      setState(() => _storeLoaded = true);
      return;
    }
    final snap = await FirebaseFirestore.instance
        .collection('stores')
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();
    setState(() {
      _storeLoaded = true;
      if (snap.docs.isNotEmpty) {
        _storeId = snap.docs.first.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemes.getBackgroundColor(context),
      body: Row(
        children: [
          const SideMenu(selected: 'Discounts'),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TopNavBar(title: 'Discounts'),
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (!_storeLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_storeId == null) {
      return const Center(
          child: Text('Танд одоогоор дэлгүүр нээгээгүй байна.'));
    }

    return StreamBuilder<List<DiscountModel>>(
      stream: _discountService.getStoreDiscounts(_storeId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final discounts = snapshot.data ?? [];
        final activeDiscounts = discounts.where((d) => d.isActive).length;
        final totalUses =
            discounts.fold<int>(0, (sum, d) => sum + d.currentUseCount);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Хөнгөлөлтийн код',
                          style: TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('Хөнгөлөлтийн код үүсгэх, засах'),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => const AddDiscountDialog(),
                      );
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Хөнгөлөлтийн код үүсгэх'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Filter row
              Row(
                children: [
                  SizedBox(
                    width: 260,
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search discounts...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<String>(
                      value: 'төлөв',
                      items: const [
                        DropdownMenuItem(value: 'төлөв', child: Text('төлөв')),
                        DropdownMenuItem(
                            value: 'идэвхтэй', child: Text('идэвхтэй')),
                        DropdownMenuItem(
                            value: 'идэвхгүй', child: Text('идэвхгүй')),
                      ],
                      onChanged: (_) {},
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 150,
                    child: DropdownButtonFormField<String>(
                      value: 'төрөл',
                      items: const [
                        DropdownMenuItem(
                            value: 'All Types', child: Text('All Types')),
                        DropdownMenuItem(
                            value: 'үнэгүй хүргэлт',
                            child: Text('үнэгүй хүргэлт')),
                        DropdownMenuItem(value: 'хувь', child: Text('хувь')),
                        DropdownMenuItem(
                            value: 'тогтмол дүн', child: Text('тогтмол дүн')),
                      ],
                      onChanged: (_) {},
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.local_offer_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text('${discounts.length} хөнгөлөлтийн код'),
                      const SizedBox(width: 16),
                      const Icon(Icons.calendar_today_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text('$activeDiscounts идэвхтэй'),
                      const SizedBox(width: 16),
                      const Icon(Icons.person_outline, size: 16),
                      const SizedBox(width: 4),
                      Text('$totalUses хэрэглэгдсэн'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Хөнгөлөлтийн код',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              discounts.isEmpty
                  ? const Text('Хөнгөлөлтийн код оруулаагүй байна.')
                  : _discountTable(discounts),
            ],
          ),
        );
      },
    );
  }

  Widget _discountTable(List<DiscountModel> discounts) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppThemes.getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppThemes.getBorderColor(context)),
      ),
      child: DataTable(
        columnSpacing: 24,
        headingRowHeight: 56,
        dataRowHeight: 64,
        headingTextStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: AppThemes.getSecondaryTextColor(context)),
        columns: [
          DataColumn(
              label: Text('хөнгөлөлтийн код',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('код',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('төрөл',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('Утга',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('Хэрэглэгдсэн тоо',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('төлөв',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
          DataColumn(
              label: Text('өөрчлөх, устгах',
                  style: TextStyle(
                      color: AppThemes.getSecondaryTextColor(context)))),
        ],
        rows: discounts.map((discount) {
          return DataRow(cells: [
            // Discount cell
            DataCell(Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.purple.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(discount.iconData, color: Colors.purple),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(discount.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppThemes.getTextColor(context))),
                  Text('Үүсгэсэн ${_formatDate(discount.createdAt)}',
                      style: TextStyle(
                          color: AppThemes.getSecondaryTextColor(context),
                          fontSize: 12)),
                ],
              ),
            ])),
            // Code cell
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppThemes.darkSurfaceVariant
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(discount.code,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppThemes.getTextColor(context))),
            )),
            // Type cell
            DataCell(Text(discount.typeDisplayName,
                style: TextStyle(color: AppThemes.getTextColor(context)))),
            // Value cell
            DataCell(Text(discount.valueDisplayText,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppThemes.getTextColor(context)))),
            // Uses cell
            DataCell(Text(
                '${discount.currentUseCount} / ${discount.maxUseCount}',
                style: TextStyle(color: AppThemes.getTextColor(context)))),
            // Status cell
            DataCell(Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: discount.isActive
                    ? Colors.green.shade200
                    : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(discount.isActive ? 'идэвхтэй' : 'идэвхгүй',
                  style: TextStyle(
                      fontSize: 12, color: AppThemes.getTextColor(context))),
            )),
            // Actions cell
            DataCell(
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _editDiscount(discount),
                    tooltip: 'Хөнгөлөлтийн код засах',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteDiscount(discount),
                    tooltip: 'Хөнгөлөлтийн код устгах',
                  ),
                ],
              ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  void _editDiscount(DiscountModel discount) {
    showDialog(
      context: context,
      builder: (_) => EditDiscountDialog(
        discountId: discount.id,
        discount: discount,
      ),
    );
  }

  void _deleteDiscount(DiscountModel discount) {
    showDialog(
      context: context,
      builder: (_) => DeleteDiscountDialog(
        discountName: discount.name,
        discountCode: discount.code,
        onConfirm: () => _confirmDeleteDiscount(discount.id, discount.name),
      ),
    );
  }

  Future<void> _confirmDeleteDiscount(
      String discountId, String discountName) async {
    try {
      await _discountService.deleteDiscount(discountId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Хөнгөлөлтийн код "$discountName" амжилттай устгагдлаа')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Хөнгөлөлтийн код устгах үед алдаа гарлаа: $e')),
        );
      }
    }
  }
}
