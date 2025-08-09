import 'package:flutter/material.dart';
import 'package:avii/features/categories/presentation/category_page.dart';
import 'package:avii/features/categories/presentation/final_category_page.dart';

class PetCategoryPage extends StatelessWidget {
  const PetCategoryPage({super.key});

  static const String _featuredStoreId = 'TLLb3tqzvU2TZSsNPol9'; // placeholder

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Амьтдын бүтээгдэхүүн',
      featuredStoreIds: const [_featuredStoreId],
      sections: const [
        'Pet',
      ],
      subCategories: [
        SubCategory(
          name: 'Амьтдын бүтээгдэхүүн',
          imageUrl: 'assets/images/categories/Pet/animal.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Амьтдын бүтээгдэхүүн',
                mainCategory: 'Pet',
                subCategory: 'Pet',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
