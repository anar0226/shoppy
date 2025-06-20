import 'package:flutter/material.dart';
import 'package:shoppy/features/categories/presentation/category_page.dart';
import 'shoes_category_page.dart';
import 'shirts_tops_category_page.dart';
import 'intimates_category_page.dart';
import 'package:shoppy/features/categories/presentation/final_category_page.dart';

class WomenCategoryPage extends StatelessWidget {
  const WomenCategoryPage({super.key});

  static const String _lalarStoreId = 'TLLb3tqzvU2TZSsNPol9';

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Women',
      featuredStoreIds: const [_lalarStoreId],
      sections: const [
        'Shirts & tops',
        'Shoes',
        'Dresses',
        'Pants',
        'Intimates',
        'Activewear',
      ],
      subCategories: [
        SubCategory(
          name: 'Shirts & tops',
          imageUrl: 'assets/images/categories/Women/WomenTshirt.jpg',
          color: const Color(0xFF2D8A47),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShirtsTopsCategoryPage()),
          ),
        ),
        SubCategory(
          name: 'Shoes',
          imageUrl: 'assets/images/categories/Women/WomenShoe.jpg',
          color: const Color(0xFFD97841),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShoesCategoryPage()),
          ),
        ),
        SubCategory(
          name: 'Dresses',
          imageUrl: 'assets/images/categories/Women/WomenDress.jpg',
          color: const Color(0xFF8B4513),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Dresses')),
          ),
        ),
        SubCategory(
          name: 'Pants',
          imageUrl: 'assets/images/categories/Women/WomenPants.jpg',
          color: const Color(0xFFB8A082),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Pants')),
          ),
        ),
        SubCategory(
          name: 'Intimates',
          imageUrl: 'assets/images/categories/Women/WomenLingerie.jpg',
          color: const Color(0xFFE8B5C8),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const IntimatesCategoryPage()),
          ),
        ),
        SubCategory(
          name: 'Activewear',
          imageUrl: 'assets/images/categories/Women/WomenActivewear.jpg',
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
