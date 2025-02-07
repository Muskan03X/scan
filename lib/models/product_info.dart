class ProductInfo {
  final String name;
  final String brand;
  final String description;
  final String category;
  final String manufacturer;
  final String imageUrl;
  final String stores;
  final String price;

  ProductInfo({
    required this.name,
    required this.brand,
    required this.description,
    required this.category,
    required this.manufacturer,
    required this.imageUrl,
    required this.stores,
    required this.price,
  });

  factory ProductInfo.fromJson(Map<String, dynamic> json) {
    final product = json['products'][0];
    return ProductInfo(
      name: product['title']?.toString() ?? 'Unknown',
      brand: product['brand']?.toString() ?? 'Unknown',
      description: product['description']?.toString() ?? 'No description available',
      category: product['category']?.toString() ?? 'Unknown',
      manufacturer: product['manufacturer']?.toString() ?? 'Unknown',
      imageUrl: product['images'] != null && product['images'] is List && product['images'].isNotEmpty 
          ? product['images'][0].toString() 
          : '',
      stores: product['stores']?.toString() ?? 'Not available',
      price: product['price']?.toString() ?? 'Not available',
    );
  }

  @override
  String toString() {
    return '''
Name: $name
Brand: $brand
Description: $description
Category: $category
Manufacturer: $manufacturer
Stores: $stores
Price: $price
''';
  }
} 