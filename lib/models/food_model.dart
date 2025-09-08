// lib/models/food_model.dart

class FoodModel {
  final String id; // Matches UUID from Supabase
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  // profileId will map to company_id from your 'foods' table
  final String? profileId; // This is used as company_id for the food

  FoodModel({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.imageUrl,
    this.profileId,
  });

  factory FoodModel.fromMap(Map<String, dynamic> map) {
    return FoodModel(
      id: map['id']?.toString() ?? '',
      name: map['name'] as String? ?? 'Unnamed Food',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      profileId: map['company_id'] as String?, // Mapped from company_id
    );
  }

  Map<String, dynamic> toJson() { // Useful if you were to insert/update foods
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'image_url': imageUrl,
      'company_id': profileId, // Maps back to company_id
    };
  }
}

