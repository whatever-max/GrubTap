// lib/models/food_model.dart
import 'company_model.dart'; // Make sure you import CompanyModel

class FoodModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final String companyId; // Keep this to link back to the company table
  final DateTime createdAt;
  final bool isFeatured;

  // Add these fields:
  final String? companyName; // To store the company name directly if joined
  final CompanyModel? company; // To store the full company object if joined

  FoodModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.imageUrl,
    required this.companyId,
    required this.createdAt,
    this.isFeatured = false,
    // Add to constructor
    this.companyName,
    this.company,
  });

  factory FoodModel.fromMap(Map<String, dynamic> map) {
    CompanyModel? parsedCompany;
    String? parsedCompanyName = map['companyName']; // If you select companyName directly

    // If your Supabase query joins the 'companies' table and returns it as a nested map
    if (map['companies'] != null && map['companies'] is Map) {
      parsedCompany = CompanyModel.fromMap(map['companies'] as Map<String, dynamic>);
      parsedCompanyName ??= parsedCompany.name; // Prioritize joined object's name
    }


    return FoodModel(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unknown Food',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      imageUrl: map['image_url'],
      companyId: map['company_id'] ?? '',
      createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']) : DateTime.now(),
      isFeatured: map['is_featured'] ?? false,
      // Assign in factory
      companyName: parsedCompanyName,
      company: parsedCompany,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'company_id': companyId,
      'created_at': createdAt.toIso8601String(),
      'is_featured': isFeatured,
      // No need to map companyName or company back for inserts usually,
      // as they are derived from relationships.
    };
  }
}
