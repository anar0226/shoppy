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
      title: 'Эрэгтэй',
      featuredStoreIds: const [_featuredStoreId],
      sections: const [
        'Гутал',
        'Гадуур хувцас',
        'Бусад',
        'Өмд',
        'Футболк',
        'Спорт хувцас',
      ],
      subCategories: [
        SubCategory(
          name: 'Гутал',
          imageUrl: 'assets/images/categories/Men/shoes.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MenShoesCategoryPage()),
          ),
        ),
        SubCategory(
          name: 'Гадуур хувцас',
          imageUrl: 'assets/images/categories/Men/jacket.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const MenJacketsTopsCategoryPage()),
          ),
        ),
        SubCategory(
          name: 'Бусад',
          imageUrl: 'assets/images/categories/Men/Others.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Бусад')),
          ),
        ),
        SubCategory(
          name: 'Өмд',
          imageUrl: 'assets/images/categories/Men/pants.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Өмд')),
          ),
        ),
        SubCategory(
          name: 'Футболк',
          imageUrl: 'assets/images/categories/Men/Tshirt.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Футболк')),
          ),
        ),
        SubCategory(
          name: 'Спорт хувцас',
          imageUrl: 'assets/images/categories/Men/Activewear.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Спорт хувцас')),
          ),
        ),
      ],
    );
  }
}
