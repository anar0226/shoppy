import 'package:flutter/material.dart';
import 'package:avii/features/categories/presentation/category_page.dart';
import 'package:avii/features/categories/presentation/final_category_page.dart';

class IntimatesCategoryPage extends StatelessWidget {
  const IntimatesCategoryPage({super.key});

  static const String _lalarStoreId = 'TLLb3tqzvU2TZSsNPol9';

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Intimates',
      featuredStoreIds: const [_lalarStoreId],
      sections: const ['Bras', 'Lingerie', 'Shapewear', 'Underwear'],
      subCategories: [
        SubCategory(
          name: 'Bras',
          imageUrl: 'assets/images/categories/Women/intimates/bra.jpg',
          color: const Color.fromARGB(255, 49, 47, 48),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Bras')),
          ),
        ),
        SubCategory(
          name: 'Lingerie',
          imageUrl: 'assets/images/categories/Women/intimates/lingerie.jpg',
          color: const Color.fromARGB(55, 230, 68, 154),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Lingerie')),
          ),
        ),
        SubCategory(
          name: 'Shapewear',
          imageUrl: 'assets/images/categories/Women/intimates/shapewear.jpg',
          color: const Color(0xFF8B4513),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Shapewear')),
          ),
        ),
        SubCategory(
          name: 'Underwear',
          imageUrl: 'assets/images/categories/Women/intimates/underwear.jpg',
          color: const Color(0xFFB8A082),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Underwear')),
          ),
        ),
      ],
    );
  }
}
