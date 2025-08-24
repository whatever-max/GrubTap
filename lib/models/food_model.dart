// lib/models/food_model.dart

class FoodModel {
  final String id; // Matches UUID from Supabase
  final String name;
  final double price;
  final String? description;
  final String? imageUrl;
  // profileId will map to company_id from your 'foods' table
  final String? profileId;

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
      // Supabase numeric type might need explicit casting if not handled by client
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      // Use 'company_id' from your database schema for profileId
      profileId: map['company_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'description': description,
      'image_url': imageUrl,
      'company_id': profileId, // Map back to company_id if you were to insert/update foods
    };
  }
}
