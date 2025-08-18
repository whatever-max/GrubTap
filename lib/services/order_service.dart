import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order_model.dart';

class OrderService {
  final SupabaseClient supabase;

  OrderService(this.supabase);

  Future<bool> canOrderNow() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 10, 30);
    final end = DateTime(now.year, now.month, now.day, 15, 30);
    return now.isAfter(start) && now.isBefore(end);
  }

  Future<String?> placeOrder({
    required String foodId,
    required String companyId,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) return 'User not logged in.';

    final canOrder = await canOrderNow();
    if (!canOrder) return 'Orders can only be placed between 10:30 and 15:30.';

    final response = await supabase.from('orders').insert({
      'user_id': user.id,
      'food_id': foodId,
      'company_id': companyId,
      'status': 'pending',
    });

    // New SDK: response is a List<dynamic> or error is thrown
    if (response is PostgrestException) {
      return 'Failed to place order: ${response.message}';
    }

    return null; // success
  }

  Future<String?> cancelOrder(String orderId) async {
    final response = await supabase
        .from('orders')
        .update({'status': 'cancelled'})
        .eq('id', orderId);

    if (response is PostgrestException) {
      return 'Failed to cancel order: ${response.message}';
    }

    return null;
  }

  Future<OrderModel?> fetchUserLatestOrder(String foodId) async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;

    final response = await supabase
        .from('orders')
        .select()
        .eq('food_id', foodId)
        .eq('user_id', user.id)
        .order('order_time', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null || response is PostgrestException) return null;

    return OrderModel.fromMap(response);
  }
}
