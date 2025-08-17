import 'company_model.dart';

class FoodModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final String companyId;
  final DateTime createdAt;
  final bool isFeatured;

  // Joined fields
  final String? companyName;
  final CompanyModel? company;

  FoodModel({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    this.imageUrl,
    required this.companyId,
    required this.createdAt,
    this.isFeatured = false,
    this.companyName,
    this.company,
  });

  factory FoodModel.fromMap(Map<String, dynamic> map) {
    // Safely parse nested company data
    CompanyModel? parsedCompany;
    String? parsedCompanyName = map['companyName']; // From manual join

    if (map['companies'] != null && map['companies'] is Map<String, dynamic>) {
      parsedCompany = CompanyModel.fromMap(map['companies']);
      parsedCompanyName ??= parsedCompany.name;
    }

    return FoodModel(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unnamed Food',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      imageUrl: map['image_url'],
      companyId: map['company_id'] ?? '',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      isFeatured: map['is_featured'] == true,
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
    };
  }
}
