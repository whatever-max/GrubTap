// lib/models/food_item_model.dart
import 'package:flutter/foundation.dart';

enum FoodItemAvailability { available, unavailable, limited }

class FoodItemModel {
  final String id; // UUID from DB
  final String companyId; // Foreign key to companies table
  String name;
  String? description;
  double price;
  String? imageUrl;
  String? category; // e.g., "Appetizer", "Main Course", "Dessert", "Drinks"
  List<String>? tags; // e.g., ["vegetarian", "spicy", "gluten-free"]
  FoodItemAvailability availability;
  int? stockCount; // Optional: if tracking stock for availability 'limited'
  DateTime createdAt;
  DateTime updatedAt;
  String? createdByUserId; // Admin/User who added this food
  String? companyName; // For display, joined from companies table

  FoodItemModel({
    required this.id,
    required this.companyId,
    required this.name,
    this.description,
    required this.price,
    this.imageUrl,
    this.category,
    this.tags,
    this.availability = FoodItemAvailability.available,
    this.stockCount,
    required this.createdAt,
    required this.updatedAt,
    this.createdByUserId,
    this.companyName,
  });

  factory FoodItemModel.fromMap(Map<String, dynamic> map) {
    String availabilityString = map['availability'] as String? ?? 'available';
    FoodItemAvailability availabilityStatus;
    switch (availabilityString.toLowerCase()) {
      case 'unavailable':
        availabilityStatus = FoodItemAvailability.unavailable;
        break;
      case 'limited':
        availabilityStatus = FoodItemAvailability.limited;
        break;
      case 'available':
      default:
        availabilityStatus = FoodItemAvailability.available;
        break;
    }

    List<String>? tagsFromDb;
    if (map['tags'] != null && map['tags'] is List) {
      // Ensure all elements are strings, filter out nulls if any
      tagsFromDb = List<String>.from(map['tags'].where((tag) => tag is String).map((tag) => tag as String));
    }


    return FoodItemModel(
      id: map['id'] as String? ?? '',
      companyId: map['company_id'] as String? ?? '',
      name: map['name'] as String? ?? 'Unnamed Food',
      description: map['description'] as String?,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: map['image_url'] as String?,
      category: map['category'] as String?,
      tags: tagsFromDb,
      availability: availabilityStatus,
      stockCount: map['stock_count'] as int?,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ?? DateTime.now(),
      createdByUserId: map['created_by_user_id'] as String?,
      companyName: map['companies'] != null ? map['companies']['name'] as String? : null,
    );
  }

  Map<String, dynamic> toMapForInsert(String adminUserId) {
    return {
      'company_id': companyId,
      'name': name,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'category': category,
      'tags': tags,
      'availability': describeEnum(availability), // Stores enum as string
      'stock_count': stockCount,
      'created_by_user_id': adminUserId,
      // 'created_at' and 'updated_at' are usually handled by DB defaults (e.g., now())
    };
  }

  Map<String, dynamic> toMapForUpdate() {
    return {
      // 'company_id': companyId, // Usually not changed after creation
      'name': name,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'category': category,
      'tags': tags,
      'availability': describeEnum(availability),
      'stock_count': stockCount,
      // 'updated_at': DateTime.now().toIso8601String(), // Or handle by DB trigger
    };
  }
}
