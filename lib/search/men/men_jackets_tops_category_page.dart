import 'package:flutter/material.dart';
import 'package:shoppy/features/categories/presentation/category_page.dart';
import 'package:shoppy/features/categories/presentation/final_category_page.dart';

/// Jackets, hoodies, polos and shirts for men.
class MenJacketsTopsCategoryPage extends StatelessWidget {
  const MenJacketsTopsCategoryPage({super.key});

  static const String _featuredStoreId = 'TLLb3tqzvU2TZSsNPol9'; // placeholder

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Jackets & Tops',
      featuredStoreIds: const [_featuredStoreId],
      sections: const [
        'Jackets',
        'Hoodies',
        'Polos',
        'Shirts',
      ],
      subCategories: [
        SubCategory(
          name: 'Jackets',
          imageUrl: 'assets/images/categories/Men/Jackets&tops/jackets.jpg',
          color: const Color(0xFF8B4513),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(title: 'Jackets'),
            ),
          ),
        ),
        SubCategory(
          name: 'Hoodies',
          imageUrl: 'assets/images/categories/Men/Jackets&tops/hoodie.jpg',
          color: const Color(0xFF6B9BD1),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(title: 'Hoodies'),
            ),
          ),
        ),
        SubCategory(
          name: 'Polos',
          imageUrl: 'assets/images/categories/Men/Jackets&tops/polo.jpg',
          color: const Color(0xFFD97841),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(title: 'Polos'),
            ),
          ),
        ),
        SubCategory(
          name: 'Shirts',
          imageUrl: 'assets/images/categories/Men/Jackets&tops/shirts.jpg',
          color: const Color(0xFFB8A082),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(title: 'Shirts'),
            ),
          ),
        ),
      ],
    );
  }
}
