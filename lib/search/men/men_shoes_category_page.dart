import 'package:flutter/material.dart';
import 'package:avii/features/categories/presentation/category_page.dart';
import 'package:avii/features/categories/presentation/final_category_page.dart';

/// Displays male footwear sub-categories.
class MenShoesCategoryPage extends StatelessWidget {
  const MenShoesCategoryPage({super.key});

  static const String _featuredStoreId = 'TLLb3tqzvU2TZSsNPol9';

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Эрэгтэй гутал',
      featuredStoreIds: const [_featuredStoreId],
      sections: const [
        'Пүүз',
        'Шаахай',
        'Гутал',
        'Спорт гутал',
      ],
      subCategories: [
        SubCategory(
          name: 'Пүүз',
          imageUrl: 'assets/images/categories/Men/shoes.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Пүүз',
                mainCategory: 'Эрэгтэй',
                subCategory: 'Гутал',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Шаахай',
          imageUrl: 'assets/images/categories/Men/shoes/slippers.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Шаахай',
                mainCategory: 'Эрэгтэй',
                subCategory: 'Гутал',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Гутал',
          imageUrl: 'assets/images/categories/Men/shoes/boots.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Гутал',
                mainCategory: 'Эрэгтэй',
                subCategory: 'Гутал',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Спорт гутал',
          imageUrl: 'assets/images/categories/Men/shoes/athletic.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Спорт гутал',
                mainCategory: 'Эрэгтэй',
                subCategory: 'Гутал',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
