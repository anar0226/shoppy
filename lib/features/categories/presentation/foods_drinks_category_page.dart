import 'package:flutter/material.dart';
import 'package:avii/features/categories/presentation/category_page.dart';
import 'package:avii/features/categories/presentation/final_category_page.dart';

class FoodsDrinksCategoryPage extends StatelessWidget {
  const FoodsDrinksCategoryPage({super.key});

  static const String _featuredStoreId = 'TLLb3tqzvU2TZSsNPol9'; // placeholder

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Хоол хүнс, ундаа',
      featuredStoreIds: const [_featuredStoreId],
      sections: const [
        'FoodsDrinks',
      ],
      subCategories: [
        SubCategory(
          name: 'Хоол хүнс, ундаа',
          imageUrl: 'assets/images/categories/Foods&drinks/foods.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Хоол хүнс, ундаа',
                mainCategory: 'FoodsDrinks',
                subCategory: 'FoodsDrinks',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
