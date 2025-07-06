import 'package:flutter/material.dart';
import '../../features/products/models/product_model.dart';

class StockIndicator extends StatelessWidget {
  final ProductModel product;
  final Map<String, String>? selectedVariants;
  final bool showQuantity;
  final bool showLowStockWarning;
  final int lowStockThreshold;

  const StockIndicator({
    super.key,
    required this.product,
    this.selectedVariants,
    this.showQuantity = true,
    this.showLowStockWarning = true,
    this.lowStockThreshold = 5,
  });

  @override
  Widget build(BuildContext context) {
    final stockInfo = _getStockInfo();

    if (!stockInfo.hasStock) {
      return _buildOutOfStockIndicator();
    }

    if (stockInfo.isLowStock && showLowStockWarning) {
      return _buildLowStockIndicator(stockInfo.quantity);
    }

    if (showQuantity) {
      return _buildInStockIndicator(stockInfo.quantity);
    }

    return _buildSimpleInStockIndicator();
  }

  StockInfo _getStockInfo() {
    if (!product.isActive) {
      return StockInfo(hasStock: false, quantity: 0, isLowStock: false);
    }

    if (selectedVariants != null && selectedVariants!.isNotEmpty) {
      // Check variant-specific stock
      bool hasVariantStock = product.isVariantInStock(selectedVariants!);
      if (!hasVariantStock) {
        return StockInfo(hasStock: false, quantity: 0, isLowStock: false);
      }

      // Calculate total stock for selected variants
      int totalStock = 0;
      for (final variant in product.variants) {
        final selectedOption = selectedVariants![variant.name];
        if (selectedOption != null) {
          totalStock += variant.getStockForOption(selectedOption);
        }
      }

      return StockInfo(
        hasStock: totalStock > 0,
        quantity: totalStock,
        isLowStock: totalStock <= lowStockThreshold,
      );
    } else {
      // Simple product stock
      return StockInfo(
        hasStock: product.stock > 0,
        quantity: product.stock,
        isLowStock: product.stock <= lowStockThreshold,
      );
    }
  }

  Widget _buildOutOfStockIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: Colors.red.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            'Дууссан',
            style: TextStyle(
              color: Colors.red.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockIndicator(int quantity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_outlined,
            size: 16,
            color: Colors.orange.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            'Цөөн үлдсэн: $quantity',
            style: TextStyle(
              color: Colors.orange.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInStockIndicator(int quantity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            'Нөөцтэй: $quantity',
            style: TextStyle(
              color: Colors.green.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleInStockIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        border: Border.all(color: Colors.green.shade200),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Colors.green.shade600,
          ),
          const SizedBox(width: 4),
          Text(
            'Нөөцтэй',
            style: TextStyle(
              color: Colors.green.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class StockInfo {
  final bool hasStock;
  final int quantity;
  final bool isLowStock;

  StockInfo({
    required this.hasStock,
    required this.quantity,
    required this.isLowStock,
  });
}

/// Widget for variant option that shows if it's out of stock
class VariantOptionChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isInStock;
  final VoidCallback? onTap;

  const VariantOptionChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.isInStock,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isInStock ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          border: Border.all(color: _getBorderColor()),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: _getTextColor(),
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            decoration: !isInStock ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor() {
    if (!isInStock) return Colors.grey.shade100;
    if (isSelected) return Colors.blue.shade50;
    return Colors.white;
  }

  Color _getBorderColor() {
    if (!isInStock) return Colors.grey.shade300;
    if (isSelected) return Colors.blue.shade400;
    return Colors.grey.shade300;
  }

  Color _getTextColor() {
    if (!isInStock) return Colors.grey.shade400;
    if (isSelected) return Colors.blue.shade700;
    return Colors.black87;
  }
}
