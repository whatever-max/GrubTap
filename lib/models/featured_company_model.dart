// lib/models/featured_company_model.dart
import 'company_model.dart';
import 'food_model.dart'; // Assuming you might have a featured food

class FeaturedCompanyModel {
  final String id;
  final String? highlightText;
  final CompanyModel company; // The actual company details
  final FoodModel? featuredFood; // Optional: if you link a specific food
  final DateTime createdAt;

  FeaturedCompanyModel({
    required this.id,
    this.highlightText,
    required this.company,
    this.featuredFood,
    required this.createdAt,
  });

  factory FeaturedCompanyModel.fromMap(Map<String, dynamic> map) {
    if (map['companies'] == null) {
      // Handle cases where the company data might be missing in the response,
      // though your query structure makes this unlikely if the join succeeds.
      throw Exception('Company data is missing in FeaturedCompanyModel.fromMap');
    }
    return FeaturedCompanyModel(
      id: map['id'] as String,
      highlightText: map['highlight_text'] as String?,
      // Assuming 'companies' is the alias for the joined company table,
      // and it's not a list but a single object because it's a FK relationship.
      company: CompanyModel.fromMap(map['companies'] as Map<String, dynamic>),
      // 'foods' would be the alias for the joined food table (if selected and present)
      featuredFood: map['foods'] != null
          ? FoodModel.fromMap(map['foods'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}