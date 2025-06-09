class Store {
  final String id;
  final String name;
  final String imageUrl;
  Store({required this.id, required this.name, required this.imageUrl});
}

class Offer {
  final String id;
  final String imageUrl;
  final String discount;
  final String storeName;
  final double rating;
  final String reviews;
  Offer({
    required this.id,
    required this.imageUrl,
    required this.discount,
    required this.storeName,
    required this.rating,
    required this.reviews,
  });
}

class SellerProduct {
  final String imageUrl;
  final String price;
  SellerProduct({required this.imageUrl, required this.price});
}
