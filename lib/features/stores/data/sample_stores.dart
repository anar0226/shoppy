import 'package:flutter/material.dart';
import '../presentation/store_screen.dart';

class SampleStores {
  static StoreData get fragmanStore => StoreData(
        id: 'fragman',
        name: 'Fragman',
        displayName: 'FRAGMAN',
        heroImageUrl:
            'https://images.unsplash.com/photo-1541643600914-78b084683601?w=800',
        backgroundColor: const Color(0xFF2C2C2C), // Dark background
        rating: 4.2,
        reviewCount: '2.1K',
        showFollowButton: true,
        hasNotification: false,
        collections: [
          StoreCollection(
            id: 'bundle',
            name: 'Bundle and Save',
            imageUrl:
                'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=400',
          ),
          StoreCollection(
            id: 'men',
            name: 'Men',
            imageUrl:
                'https://images.unsplash.com/photo-1564859228273-274232fdb516?w=400',
          ),
          StoreCollection(
            id: 'women',
            name: 'Women',
            imageUrl:
                'https://images.unsplash.com/photo-1594633312681-425c7b97ccd1?w=400',
          ),
        ],
        categories: ['All', 'Bundle and Save', 'Men', 'Women', 'Unisex'],
        productCount: 262,
        products: [
          StoreProduct(
            id: 'fragrance1',
            name: 'Jean Paul Gaultier Collection',
            imageUrl:
                'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=400',
            price: 89.99,
            discount: 14,
          ),
          StoreProduct(
            id: 'fragrance2',
            name: 'Jean Paul Gaultier Le Beau',
            imageUrl:
                'https://images.unsplash.com/photo-1541643600914-78b084683601?w=400',
            price: 129.99,
          ),
          StoreProduct(
            id: 'fragrance3',
            name: 'Luxury Fragrance Set',
            imageUrl:
                'https://images.unsplash.com/photo-1564859228273-274232fdb516?w=400',
            price: 199.99,
            discount: 25,
          ),
          StoreProduct(
            id: 'fragrance4',
            name: 'Premium Cologne',
            imageUrl:
                'https://images.unsplash.com/photo-1588159343745-445d6f161a4e?w=400',
            price: 79.99,
          ),
        ],
      );

  static StoreData get mrBeastStore => StoreData(
        id: 'mrbeast',
        name: 'MrBeast.store',
        displayName: 'MRBEAST\n.STORE',
        heroImageUrl:
            'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=800',
        backgroundColor: const Color(0xFF01BCE7), // Bright cyan
        rating: 4.6,
        reviewCount: '8.3K',
        showFollowButton: false,
        hasNotification: true,
        collections: [
          StoreCollection(
            id: 'beastgames',
            name: 'BEAST GAMES',
            imageUrl:
                'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=400',
          ),
        ],
        categories: ['All', 'NEW', 'KIDS', 'TOPS', 'BOTTOMS', 'ACCESSORIES'],
        productCount: 156,
        products: [
          StoreProduct(
            id: 'beast1',
            name: 'Beast Games T-Shirt',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 29.99,
          ),
          StoreProduct(
            id: 'beast2',
            name: 'MrBeast Hoodie',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 49.99,
            discount: 20,
          ),
          StoreProduct(
            id: 'beast3',
            name: 'Beast Mode Cap',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 24.99,
          ),
          StoreProduct(
            id: 'beast4',
            name: 'Gaming Jersey',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 39.99,
            discount: 15,
          ),
          StoreProduct(
            id: 'beast5',
            name: 'Logo Socks',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 9.99,
          ),
          StoreProduct(
            id: 'beast6',
            name: 'Beast Wristband',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 4.99,
          ),
          StoreProduct(
            id: 'beast7',
            name: 'Limited Poster',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 14.99,
          ),
          StoreProduct(
            id: 'beast8',
            name: 'Beanie',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 19.99,
          ),
          StoreProduct(
            id: 'beast9',
            name: 'Sticker Pack',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 5.99,
          ),
          StoreProduct(
            id: 'beast10',
            name: 'Mouse Pad',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 12.99,
          ),
          StoreProduct(
            id: 'beast11',
            name: 'Phone Case',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 17.99,
          ),
          StoreProduct(
            id: 'beast12',
            name: 'Water Bottle',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 24.99,
          ),
          StoreProduct(
            id: 'beast13',
            name: 'Gaming Headset',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 79.99,
            discount: 10,
          ),
          StoreProduct(
            id: 'beast14',
            name: 'Laptop Sleeve',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 34.99,
          ),
          StoreProduct(
            id: 'beast15',
            name: 'Keychain',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 7.99,
          ),
          StoreProduct(
            id: 'beast16',
            name: 'Backpack',
            imageUrl: 'assets/images/placeholders/ASAP.jpg',
            price: 59.99,
            discount: 25,
          ),
        ],
      );

  static List<StoreData> get allStores => [
        fragmanStore,
        mrBeastStore,
      ];

  static StoreData? getStoreById(String id) {
    try {
      return allStores.firstWhere((store) => store.id == id);
    } catch (e) {
      return null;
    }
  }
}
