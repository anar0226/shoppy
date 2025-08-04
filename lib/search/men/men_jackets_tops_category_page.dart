import 'package:flutter/material.dart';
import 'package:avii/features/categories/presentation/category_page.dart';
import 'package:avii/features/categories/presentation/final_category_page.dart';

/// Jackets, hoodies, polos and shirts for men.
class MenJacketsTopsCategoryPage extends StatelessWidget {
  const MenJacketsTopsCategoryPage({super.key});

  static const String _featuredStoreId = 'TLLb3tqzvU2TZSsNPol9'; // placeholder

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Гадуур хувцас',
      featuredStoreIds: const [_featuredStoreId],
      sections: const [
        'куртка',
        'Малгайтай цамц',
        'Поло',
        'Цамц',
      ],
      subCategories: [
        SubCategory(
          name: 'куртка',
          imageUrl: 'assets/images/categories/Men/Jackets&tops/jackets.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(title: 'куртка'),
            ),
          ),
        ),
        SubCategory(
          name: 'Малгайтай цамц',
          imageUrl: 'assets/images/categories/Men/Jackets&tops/hoodie.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(title: 'Малгайтай цамц'),
            ),
          ),
        ),
        SubCategory(
          name: 'Поло',
          imageUrl: 'assets/images/categories/Men/Jackets&tops/polo.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(title: 'Поло'),
            ),
          ),
        ),
        SubCategory(
          name: 'Цамц',
          imageUrl: 'assets/images/categories/Men/Jackets&tops/shirts.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(title: 'Цамц'),
            ),
          ),
        ),
      ],
    );
  }
}
