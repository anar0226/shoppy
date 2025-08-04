import 'package:flutter/material.dart';
import 'package:avii/features/categories/presentation/category_page.dart';
import 'shoes_category_page.dart';
import 'shirts_tops_category_page.dart';
import 'intimates_category_page.dart';
import 'package:avii/features/categories/presentation/final_category_page.dart';

class WomenCategoryPage extends StatelessWidget {
  const WomenCategoryPage({super.key});

  static const String _lalarStoreId = 'TLLb3tqzvU2TZSsNPol9';

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Эмэгтэй',
      featuredStoreIds: const [_lalarStoreId],
      sections: const [
        'Гадуур хувцас & Футболк',
        'Гутал',
        'Даашинз',
        'Өмд',
        'Дотуур хувцас',
        'Спорт хувцас',
      ],
      subCategories: [
        SubCategory(
          name: 'Гадуур хувцас & Футболк',
          imageUrl: 'assets/images/categories/Women/WomenTshirt.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShirtsTopsCategoryPage()),
          ),
        ),
        SubCategory(
          name: 'Эмэгтэй гутал',
          imageUrl: 'assets/images/categories/Women/WomenShoe.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ShoesCategoryPage()),
          ),
        ),
        SubCategory(
          name: 'Даашинз',
          imageUrl: 'assets/images/categories/Women/WomenDress.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Даашинз')),
          ),
        ),
        SubCategory(
          name: 'Өмд',
          imageUrl: 'assets/images/categories/Women/WomenPants.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Өмд')),
          ),
        ),
        SubCategory(
          name: 'Дотуур хувцас',
          imageUrl: 'assets/images/categories/Women/WomenLingerie.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const IntimatesCategoryPage()),
          ),
        ),
        SubCategory(
          name: 'Актив хувцас',
          imageUrl: 'assets/images/categories/Women/WomenActivewear.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FinalCategoryPage(title: 'Актив хувцас')),
          ),
        ),
      ],
    );
  }
}
