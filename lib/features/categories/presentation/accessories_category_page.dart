import 'package:flutter/material.dart';
import 'package:avii/features/categories/presentation/category_page.dart';
import 'package:avii/features/categories/presentation/final_category_page.dart';

class AccessoriesCategoryPage extends StatelessWidget {
  const AccessoriesCategoryPage({super.key});

  static const String _featuredStoreId = 'TLLb3tqzvU2TZSsNPol9'; // placeholder

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Аксессуары',
      featuredStoreIds: const [_featuredStoreId],
      sections: const [
        'Belts',
        'Hats',
        'Jewelry',
        'Sunglasses',
        'Wallets',
        'Others',
      ],
      subCategories: [
        SubCategory(
          name: 'Бүс',
          imageUrl: 'assets/images/categories/Accessories/belts.jpg',
          color: const Color(0xFF654321),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Бүс',
                mainCategory: 'Accessories',
                subCategory: 'Belts',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Малгай',
          imageUrl: 'assets/images/categories/Accessories/hats.jpg',
          color: const Color.fromARGB(255, 182, 214, 196),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Малгай',
                mainCategory: 'Accessories',
                subCategory: 'Hats',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Гоёл чимэглэл',
          imageUrl: 'assets/images/categories/Accessories/jewelry.jpg',
          color: const Color.fromARGB(255, 215, 213, 202),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Гоёл чимэглэл',
                mainCategory: 'Accessories',
                subCategory: 'Jewelry',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Нарны шил',
          imageUrl: 'assets/images/categories/Accessories/sunglasses.jpg',
          color: const Color(0xFF1F1F1F),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Нарны шил',
                mainCategory: 'Accessories',
                subCategory: 'Sunglasses',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Түрийвч',
          imageUrl: 'assets/images/categories/Accessories/wallets.jpg',
          color: const Color.fromARGB(255, 196, 194, 193),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Түрийвч',
                mainCategory: 'Accessories',
                subCategory: 'Wallets',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Бусад',
          imageUrl: 'assets/images/categories/Accessories/others.jpg',
          color: const Color(0xFF708090),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Бусад',
                mainCategory: 'Accessories',
                subCategory: 'Others',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
