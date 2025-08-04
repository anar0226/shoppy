import 'package:flutter/material.dart';
import 'package:avii/features/categories/presentation/category_page.dart';
import 'package:avii/features/categories/presentation/final_category_page.dart';

class BeautyCategoryPage extends StatelessWidget {
  const BeautyCategoryPage({super.key});

  static const String _featuredStoreId = 'TLLb3tqzvU2TZSsNPol9'; // placeholder

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Гоо сайxан',
      featuredStoreIds: const [_featuredStoreId],
      sections: const [
        'Haircare',
        'Makeup',
        'Nailcare',
        'Perfume',
        'Skincare',
        'Others',
      ],
      subCategories: [
        SubCategory(
          name: 'Үс арчилгаа',
          imageUrl: 'assets/images/categories/Beauty/haircare.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Үс арчилгаа',
                mainCategory: 'Beauty',
                subCategory: 'Haircare',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Нүүр будалт',
          imageUrl: 'assets/images/categories/Beauty/makeup.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Нүүр будалт',
                mainCategory: 'Beauty',
                subCategory: 'Makeup',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Хумс арчилгаа',
          imageUrl: 'assets/images/categories/Beauty/nailcare.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Хумс арчилгаа',
                mainCategory: 'Beauty',
                subCategory: 'Nailcare',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Үнэртэй ус',
          imageUrl: 'assets/images/categories/Beauty/perfume.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Үнэртэй ус',
                mainCategory: 'Beauty',
                subCategory: 'Perfume',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Арьс арчилгаа',
          imageUrl: 'assets/images/categories/Beauty/skincare.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Арьс арчилгаа',
                mainCategory: 'Beauty',
                subCategory: 'Skincare',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Бусад',
          imageUrl: 'assets/images/categories/Beauty/others.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Бусад',
                mainCategory: 'Beauty',
                subCategory: 'Others',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
