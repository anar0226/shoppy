import 'package:flutter/material.dart';
import 'package:avii/features/categories/presentation/category_page.dart';
import 'package:avii/features/categories/presentation/final_category_page.dart';

class ElectronicsCategoryPage extends StatelessWidget {
  const ElectronicsCategoryPage({super.key});

  static const String _featuredStoreId = 'TLLb3tqzvU2TZSsNPol9'; // placeholder

  @override
  Widget build(BuildContext context) {
    return CategoryPage(
      title: 'Цахилгаан бараа',
      featuredStoreIds: const [_featuredStoreId],
      sections: const [
        'Headphones',
        'Phones',
        'PhoneAccessories',
        'ComputerAccessories',
      ],
      subCategories: [
        SubCategory(
          name: 'Чихэвч',
          imageUrl: 'assets/images/categories/electronics/Headphones.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Чихэвч',
                mainCategory: 'Electronics',
                subCategory: 'Headphones',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Гар утас',
          imageUrl: 'assets/images/categories/electronics/phone.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Гар утас',
                mainCategory: 'Electronics',
                subCategory: 'Phones',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Утасны дагалдах хэрэгсэлүүд',
          imageUrl: 'assets/images/categories/electronics/PhoneAccessories.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Утасны дагалдах хэрэгсэлүүд',
                mainCategory: 'Electronics',
                subCategory: 'PhoneAccessories',
              ),
            ),
          ),
        ),
        SubCategory(
          name: 'Компьютерийн дагалдах хэрэгсэлүүд',
          imageUrl:
              'assets/images/categories/electronics/computerAccessories.jpg',
          color: const Color(0xFF808080), // Grey color
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const FinalCategoryPage(
                title: 'Компьютерийн дагалдах хэрэгсэлүүд',
                mainCategory: 'Electronics',
                subCategory: 'ComputerAccessories',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
