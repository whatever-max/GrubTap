// lib/models/order_model.dart
class OrderModel {
  final String id;
  final String userId;
  final String foodId;
  final String companyId;
  final DateTime orderTime;
  final String status;

  OrderModel({
    required this.id,
    required this.userId,
    required this.foodId,
    required this.companyId,
    required this.orderTime,
    required this.status,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    return OrderModel(
      id: map['id'],
      userId: map['user_id'],
      foodId: map['food_id'],
      companyId: map['company_id'],
      orderTime: DateTime.parse(map['order_time']),
      status: map['status'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'food_id': foodId,
      'company_id': companyId,
      'order_time': orderTime.toIso8601String(),
      'status': status,
    };
  }
}
