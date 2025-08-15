class BannerModel {
  final String id;
  final String? title;
  final String? imageUrl;

  BannerModel({
    required this.id,
    this.title,
    this.imageUrl,
  });

  factory BannerModel.fromMap(Map<String, dynamic> map) {
    return BannerModel(
      id: map['id'] ?? '',
      title: map['title'],
      imageUrl: map['image_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'image_url': imageUrl,
    };
  }
}
