import 'package:flutter/material.dart';
import 'package:avii/features/categories/presentation/category_page.dart';
import 'package:avii/features/categories/presentation/final_category_page.dart';

class ToysGamesCategoryPage extends StatelessWidget {
  const ToysGamesCategoryPage({super.key});

  static const String _featuredStoreId = 'TLLb3tqzvU2TZSsNPol9'; // placeholder

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Тоглоомнууд',
      featuredStoreIds: const [_featuredStoreId],
      sections: const [
        'ToysGames',
      ],
      subCategories: [
        SubCategory(
          name: 'Тоглоомнууд',
          imageUrl: 'assets/images/categories/Toys&games/toys and games.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Тоглоомнууд',
                mainCategory: 'ToysGames',
                subCategory: 'ToysGames',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
