import 'package:flutter/material.dart';
import 'package:avii/features/categories/presentation/category_page.dart';
import 'package:avii/features/categories/presentation/final_category_page.dart';

class FitnessCategoryPage extends StatelessWidget {
  const FitnessCategoryPage({super.key});

  static const String _featuredStoreId = 'TLLb3tqzvU2TZSsNPol9'; // placeholder

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Фитнесс',
      featuredStoreIds: const [_featuredStoreId],
      sections: const [
        'FitnessEquipment',
        'Supplements',
      ],
      subCategories: [
        SubCategory(
          name: 'Фитнесс тоног төхөөрөмж',
          imageUrl: 'assets/images/categories/Fitness/FitnessEquipment.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Фитнесс тоног төхөөрөмж',
                mainCategory: 'Fitness',
                subCategory: 'FitnessEquipment',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Витамин ба нэмэлт бэлдмэлүүд',
          imageUrl: 'assets/images/categories/Fitness/Supplement.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Витамин ба нэмэлт бэлдмэлүүд',
                mainCategory: 'Fitness',
                subCategory: 'Supplements',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
