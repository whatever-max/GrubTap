class CompanyModel {
  final String id;
  final String name;
  final String? description;
  final String? logoUrl;

  CompanyModel({
    required this.id,
    required this.name,
    this.description,
    this.logoUrl,
  });

  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    return CompanyModel(
      id: map['id'] ?? '',
      name: map['name'] ?? 'Unnamed Company',
      description: map['description'],
      logoUrl: map['logo_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'logo_url': logoUrl,
    };
  }
}
