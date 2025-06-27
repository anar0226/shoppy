import 'package:flutter/material.dart';
import 'package:avii/features/categories/presentation/category_page.dart';
import 'package:avii/features/categories/presentation/final_category_page.dart';
import 'package:avii/search/men/men_shoes_category_page.dart';
import 'package:avii/search/men/men_jackets_tops_category_page.dart';

class MenCategoryPage extends StatelessWidget {
  const MenCategoryPage({super.key});

  static const String _featuredStoreId = 'TLLb3tqzvU2TZSsNPol9'; // placeholder

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Men',
      featuredStoreIds: const [_featuredStoreId],
      sections: const [
        'Shoes',
        'Jackets & Tops',
        'Others',
        'Pants',
        'Tshirts',
        'Activewear',
      ],
      subCategories: [
        SubCategory(
          name: 'Shoes',
          imageUrl: 'assets/images/categories/Men/shoes.jpg',
          color: const Color(0xFF2D8A47),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MenShoesCategoryPage()),
          ),
        ),
        SubCategory(
          name: 'Jackets & Tops',
          imageUrl: 'assets/images/categories/Men/jacket.jpg',
          color: const Color(0xFFD97841),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const MenJacketsTopsCategoryPage()),
          ),
        ),
        SubCategory(
          name: 'Others',
          imageUrl: 'assets/images/categories/Men/Others.jpg',
          color: const Color(0xFF8B4513),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Others')),
          ),
        ),
        SubCategory(
          name: 'Pants',
          imageUrl: 'assets/images/categories/Men/pants.jpg',
          color: const Color(0xFFB8A082),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Pants')),
          ),
        ),
        SubCategory(
          name: 'Tshirts',
          imageUrl: 'assets/images/categories/Men/Tshirt.jpg',
          color: const Color(0xFFE8B5C8),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Tshirts')),
          ),
        ),
        SubCategory(
          name: 'Activewear',
          imageUrl: 'assets/images/categories/Men/Activewear.jpg',
          color: const Color(0xFF6B9BD1),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Activewear')),
          ),
        ),
      ],
    );
  }
}
