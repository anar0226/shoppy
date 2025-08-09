import 'package:flutter/material.dart';
import 'package:avii/features/categories/presentation/category_page.dart';
import 'package:avii/features/categories/presentation/final_category_page.dart';

class HomeCategoryPage extends StatelessWidget {
  const HomeCategoryPage({super.key});

  static const String _featuredStoreId = 'TLLb3tqzvU2TZSsNPol9'; // placeholder

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Гэр ахуй',
      featuredStoreIds: const [_featuredStoreId],
      sections: const [
        'Home',
      ],
      subCategories: [
        SubCategory(
          name: 'Гэр ахуй',
          imageUrl: 'assets/images/categories/Home/home.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Гэр ахуй',
                mainCategory: 'Home',
                subCategory: 'Home',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
