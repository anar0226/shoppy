import 'package:flutter/material.dart';
import 'package:shoppy/features/categories/presentation/category_page.dart';
import 'package:shoppy/features/categories/presentation/final_category_page.dart';

/// Displays male footwear sub-categories.
class MenShoesCategoryPage extends StatelessWidget {
  const MenShoesCategoryPage({super.key});

  // TODO: replace with real featured store IDs once available
  static const String _featuredStoreId = 'TLLb3tqzvU2TZSsNPol9';

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Men Shoes',
      featuredStoreIds: const [_featuredStoreId],
      sections: const [
        'Sneakers',
        'Slippers',
        'Boots',
        'Athletic shoes',
      ],
      subCategories: [
        SubCategory(
          name: 'Sneakers',
          imageUrl: 'assets/images/categories/Men/shoes.jpg',
          color: const Color(0xFF6B9BD1),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(title: 'Sneakers'),
            ),
          ),
        ),
        SubCategory(
          name: 'Slippers',
          imageUrl: 'assets/images/categories/Men/shoes/slippers.jpg',
          color: const Color(0xFFD97841),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(title: 'Slippers'),
            ),
          ),
        ),
        SubCategory(
          name: 'Boots',
          imageUrl: 'assets/images/categories/Men/shoes/boots.jpg',
          color: const Color(0xFF8B4513),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(title: 'Boots'),
            ),
          ),
        ),
        SubCategory(
          name: 'Athletic shoes',
          imageUrl: 'assets/images/categories/Men/shoes/athletic.jpg',
          color: const Color(0xFF2D8A47),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(title: 'Athletic shoes'),
            ),
          ),
        ),
      ],
    );
  }
}
