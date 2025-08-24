// lib/models/company_model.dart

class CompanyModel {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? createdByUserId; // From public.companies.created_by
  final DateTime createdAt;
  final String? createdByUsername; // From the joined users table

  CompanyModel({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.createdByUserId,
    required this.createdAt,
    this.createdByUsername,
  });

  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    // Helper to safely parse DateTime
    DateTime parseDate(String? dateStr) {
      if (dateStr == null) return DateTime.now(); // Or throw error, or default
      try {
        return DateTime.parse(dateStr);
      } catch (e) {
        return DateTime.now(); // Fallback for invalid date format
      }
    }

    // Handle nested 'users' data for createdByUsername
    String? username;
    if (map['users'] != null && map['users'] is Map) {
      username = map['users']['username'] as String?;
    }


    return CompanyModel(
      id: map['id'] as String? ?? 'UNKNOWN_ID', // ID should always exist from DB
      name: map['name'] as String? ?? 'Unnamed Company',
      description: map['description'] as String?,
      logoUrl: map['logo_url'] as String?,
      createdByUserId: map['created_by'] as String?,
      createdAt: parseDate(map['created_at'] as String?),
      createdByUsername: username ?? (map['created_by'] != null ? 'User ID: ${map['created_by']}' : 'Unknown Creator'),
    );
  }

  Map<String, dynamic> toMapForUpdate() { // For updating existing company
    return {
      'name': name,
      if (description != null) 'description': description,
      if (logoUrl != null) 'logo_url': logoUrl,
      // id, created_by, created_at are typically not updated this way
    };
  }

  Map<String, dynamic> toMapForInsert(String currentAdminUserId) { // For creating new company
    return {
      'name': name,
      if (description != null) 'description': description,
      if (logoUrl != null) 'logo_url': logoUrl,
      'created_by': currentAdminUserId,
      // created_at is handled by DB default
    };
  }
}

