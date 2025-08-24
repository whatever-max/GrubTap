// lib/models/order_model.dart
import 'package:flutter/foundation.dart'; // For describeEnum

// Sub-model for parsed order items, useful if you need typed access
class ParsedOrderItem {
  final int quantity;
  final double itemPrice; // Price per item at the time of order
  final String? foodId;
  final String? foodName;
  // Add other food details if needed, e.g., foodPriceAtOrderTime

  ParsedOrderItem({
    required this.quantity,
    required this.itemPrice,
    this.foodId,
    this.foodName,
  });

  factory ParsedOrderItem.fromMap(Map<String, dynamic> itemMap) {
    String? fName;
    if (itemMap['foods'] != null && itemMap['foods'] is Map) {
      fName = (itemMap['foods'] as Map<String, dynamic>)['name'] as String?;
    }

    return ParsedOrderItem(
      quantity: (itemMap['quantity'] as int?) ?? 0,
      itemPrice: (itemMap['item_price'] as num?)?.toDouble() ?? 0.0,
      foodId: itemMap['foods'] != null && itemMap['foods'] is Map ? (itemMap['foods'] as Map<String, dynamic>)['id'] as String? : null,
      foodName: fName,
    );
  }
}


enum AdminOrderStatus {
  pending,
  confirmed,
  preparing,
  readyForPickup,
  completed,
  cancelled,
  unknown
}

class OrderModel {
  final String id;
  final String userId;
  final String? foodId; // Original direct link, less used if order_items is primary
  final String companyId;
  final DateTime orderTime;
  AdminOrderStatus status;

  // These will now be calculated from order_items if not present in the main 'orders' table response
  final int quantity; // Total quantity of all items in the order
  final double totalPrice; // Total price of the entire order

  String? userEmail;
  String? userName;
  String? companyName;
  String? foodNameDisplay; // A summary display name like "Burger & more"

  final List<ParsedOrderItem> items; // To store the parsed order items

  OrderModel({
    required this.id,
    required this.userId,
    this.foodId,
    required this.companyId,
    required this.orderTime,
    required this.status,
    required this.quantity,
    required this.totalPrice,
    this.userEmail,
    this.userName,
    this.foodNameDisplay,
    this.companyName,
    required this.items,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    AdminOrderStatus currentStatus;
    final statusString = map['status'] as String? ?? 'unknown';
    try {
      currentStatus = AdminOrderStatus.values.firstWhere(
            (e) => describeEnum(e).toLowerCase() == statusString.toLowerCase(),
      );
    } catch (_) {
      currentStatus = AdminOrderStatus.unknown;
    }

    List<ParsedOrderItem> parsedItems = [];
    if (map['order_items'] != null && map['order_items'] is List) {
      for (var itemMap in (map['order_items'] as List)) {
        if (itemMap is Map<String, dynamic>) {
          parsedItems.add(ParsedOrderItem.fromMap(itemMap));
        }
      }
    }

    // Calculate total quantity and price from items if not directly on order
    int calculatedQuantity = 0;
    double calculatedTotalPrice = 0;
    String? displayFoodName;

    if (parsedItems.isNotEmpty) {
      for (var item in parsedItems) {
        calculatedQuantity += item.quantity;
        calculatedTotalPrice += item.quantity * item.itemPrice;
      }
      displayFoodName = parsedItems.first.foodName;
      if (parsedItems.length > 1) {
        displayFoodName = "$displayFoodName & more";
      }
    } else if (map['foods'] != null && map['foods']['name'] != null) {
      // Fallback if no order_items but direct food link exists
      displayFoodName = map['foods']['name'] as String?;
    }


    return OrderModel(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      foodId: map['food_id'] as String?,
      companyId: map['company_id'] as String? ?? '',
      orderTime: DateTime.tryParse(map['order_time'] as String? ?? '') ?? DateTime.now(),
      status: currentStatus,
      // Use quantity from 'orders' table if present, otherwise use calculated from items
      quantity: (map['quantity'] as int?) ?? calculatedQuantity,
      // Use total_price from 'orders' table if present, otherwise use calculated from items
      totalPrice: (map['total_price'] as num?)?.toDouble() ?? calculatedTotalPrice,
      userEmail: map['users'] != null ? map['users']['email'] as String? : null,
      userName: map['users'] != null
          ? (map['users']['username'] as String? ??
          "${map['users']['first_name'] ?? ''} ${map['users']['last_name'] ?? ''}".trim())
          : null,
      companyName: map['companies'] != null ? map['companies']['name'] as String? : null,
      foodNameDisplay: displayFoodName,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toMapForUpdate() {
    return {
      'status': describeEnum(status),
    };
  }
}

