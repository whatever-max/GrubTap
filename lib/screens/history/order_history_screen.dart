// lib/screens/history/order_history_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:grubtap/utils/string_extensions.dart'; // Make sure this file exists and provides capitalizeFirst()
import 'package:grubtap/screens/edit_order/edit_order_screen.dart'; // Ensure this path is correct

// THIS IS THE DEFINITIVE LOCATION FOR OrderHistoryDisplayItem
class OrderHistoryDisplayItem {
  final String id;
  final String foodName;
  final double totalPrice;
  final int totalQuantity;
  final String status;
  final DateTime orderTime; // Local time
  final DateTime? lastEditedAt; // Local time
  final bool canDelete;
  final bool canEdit; // This is always true from the model's perspective now
  final List<Map<String, dynamic>> rawOrderItems;

  OrderHistoryDisplayItem({
    required this.id,
    required this.foodName,
    required this.totalPrice,
    required this.totalQuantity,
    required this.status,
    required this.orderTime,
    this.lastEditedAt,
    required this.canDelete,
    required this.canEdit,
    required this.rawOrderItems,
  });

  factory OrderHistoryDisplayItem.fromMap(Map<String, dynamic> map) {
    DateTime orderDateTime = DateTime.parse(map['order_time'] as String).toLocal();
    String currentStatus = map['status']?.toString().toLowerCase() ?? 'unknown';

    DateTime? lastEditedDateTime;
    if (map['last_edited_at'] != null) {
      lastEditedDateTime = DateTime.parse(map['last_edited_at'] as String).toLocal();
    }

    // canEdit is now always true from the model, check happens on tap in _navigateToEditOrder
    const bool modelCanEditFlag = true;

    bool isDeletable = false;
    final deletableStatusesForHistory = ['completed', 'cancelled', 'failed', 'deleted', 'cancelled_by_user'];
    if (deletableStatusesForHistory.contains(currentStatus) &&
        DateTime.now().difference(orderDateTime).inHours >= 24) {
      isDeletable = true;
    }

    String displayFoodName = 'N/A';
    double calculatedTotalPrice = 0.0;
    int calculatedTotalQuantity = 0;
    List<Map<String, dynamic>> rawItems = [];
    final orderItemsList = map['order_items'] as List<dynamic>? ?? [];

    if (orderItemsList.isNotEmpty) {
      List<String> distinctFoodNamesInOrder = [];
      for (var itemEntry in orderItemsList) {
        final itemMap = itemEntry as Map<String, dynamic>;
        Map<String, dynamic>? foodDetails = itemMap['foods'] as Map<String, dynamic>?;
        final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
        final itemPrice = (itemMap['item_price'] as num?)?.toDouble() ?? 0.0;
        rawItems.add({
          'quantity': quantity,
          'item_price': itemPrice,
          'food_id': foodDetails?['id'],
          'foods': foodDetails // Contains name, id, price from the join
        });
        calculatedTotalPrice += quantity * itemPrice;
        calculatedTotalQuantity += quantity;
        if (foodDetails != null && foodDetails['name'] != null) {
          String itemName = foodDetails['name'] as String;
          if (!distinctFoodNamesInOrder.contains(itemName)) distinctFoodNamesInOrder.add(itemName);
        }
      }
      if (distinctFoodNamesInOrder.isNotEmpty) {
        displayFoodName = distinctFoodNamesInOrder.first;
        if (distinctFoodNamesInOrder.length > 1) displayFoodName += " & more";
      }
    } else if (map['foods'] != null && map['foods']['name'] != null) { // Fallback for direct food link on 'orders'
      displayFoodName = map['foods']['name'] as String;
      final directFoodPrice = (map['foods']['price'] as num?)?.toDouble() ?? 0.0;
      calculatedTotalQuantity = 1; // Assume quantity 1 for direct link
      calculatedTotalPrice = directFoodPrice;
      if (map['food_id'] != null) { // Ensure food_id is present for rawItem
        rawItems.add({
          'quantity': 1,
          'item_price': directFoodPrice,
          'food_id': map['food_id'],
          'foods': map['foods'] // Contains name, id, price from the join
        });
      }
    } else {
      displayFoodName = "Order details unavailable";
    }

    return OrderHistoryDisplayItem(
      id: map['id'].toString(),
      foodName: displayFoodName,
      totalPrice: calculatedTotalPrice,
      totalQuantity: calculatedTotalQuantity,
      status: currentStatus,
      orderTime: orderDateTime,
      lastEditedAt: lastEditedDateTime,
      canDelete: isDeletable,
      canEdit: modelCanEditFlag, // Always true
      rawOrderItems: rawItems,
    );
  }
}

class OrderHistoryScreen extends StatefulWidget {
  static const String routeName = '/order-history';
  const OrderHistoryScreen({super.key});
  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final supabase = Supabase.instance.client;
  List<OrderHistoryDisplayItem> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrderHistory();
  }

  Future<void> _loadOrderHistory() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) setState(() { _errorMessage = "User not logged in."; _isLoading = false; });
        return;
      }
      final response = await supabase
          .from('orders')
          .select('''
            id, status, order_time, last_edited_at, user_id, company_id, food_id,
            foods (id, name, price),
            order_items (quantity, item_price, food_id, foods (id, name, price))
          ''')
          .eq('user_id', userId)
          .neq('status', 'archived')
          .order('order_time', ascending: false);

      if (!mounted) return;
      _orders = response.map((item) => OrderHistoryDisplayItem.fromMap(item as Map<String, dynamic>)).toList();
      setState(() { _isLoading = false; });
    } on PostgrestException catch (e) {
      debugPrint("OrderHistoryScreen: Supabase Error loading history: ${e.code} - ${e.message}");
      if (mounted) setState(() { _errorMessage = "Failed to load history: ${e.message}"; _isLoading = false; });
    } catch (e) {
      debugPrint("OrderHistoryScreen: Generic error loading history: $e");
      if (mounted) setState(() { _errorMessage = "An unexpected error: ${e.toString()}"; _isLoading = false; });
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to mark this order as deleted?'),
        actions: <Widget>[
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (confirmDelete != true || !mounted) return;

    final orderIndex = _orders.indexWhere((o) => o.id == orderId);
    OrderHistoryDisplayItem? removedOrder; // Store for potential rollback
    if (orderIndex != -1) {
      removedOrder = _orders[orderIndex];
      setState(() => _orders.removeAt(orderIndex)); // Optimistic UI removal
    }

    try {
      await supabase.from('orders').update({'status': 'deleted'}).eq('id', orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order marked as deleted.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint("OrderHistoryScreen: Error deleting order: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error));
        // Rollback optimistic removal if DB call failed
        if (removedOrder != null && orderIndex != -1) {
          setState(() => _orders.insert(orderIndex, removedOrder!));
        } else {
          _loadOrderHistory(); // Fallback to full reload if optimistic removal info is lost
        }
      }
    }
  }

  void _navigateToEditOrder(OrderHistoryDisplayItem orderToEdit) {
    final DateTime now = DateTime.now();
    final DateTime orderTime = orderToEdit.orderTime; // Already in local time

    const int cycleStartHour = 15;
    const int cycleStartMinute = 31;
    const int editDeadlineHour = 10;
    const int editDeadlineMinute = 30;

    DateTime operationalDayStartForThisOrder;
    if (orderTime.hour < cycleStartHour ||
        (orderTime.hour == cycleStartHour && orderTime.minute < cycleStartMinute)) {
      operationalDayStartForThisOrder = DateTime(
          orderTime.year, orderTime.month, orderTime.day - 1,
          cycleStartHour, cycleStartMinute
      );
    } else {
      operationalDayStartForThisOrder = DateTime(
          orderTime.year, orderTime.month, orderTime.day,
          cycleStartHour, cycleStartMinute
      );
    }

    final DateTime deadlineForThisOrder = DateTime(
        operationalDayStartForThisOrder.year,
        operationalDayStartForThisOrder.month,
        operationalDayStartForThisOrder.day + 1,
        editDeadlineHour,
        editDeadlineMinute
    );

    debugPrint("[EditCheck] Order ID: ${orderToEdit.id}, Order Time: $orderTime, Now: $now");
    debugPrint("[EditCheck] Op Day Start: $operationalDayStartForThisOrder, Edit Deadline: $deadlineForThisOrder");

    bool canCurrentlyEdit = now.isBefore(deadlineForThisOrder);

    if (canCurrentlyEdit) {
      debugPrint("[EditCheck] CAN edit.");
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => EditOrderScreen(orderToEdit: orderToEdit)),
      ).then((orderWasUpdated) {
        if (orderWasUpdated == true) _loadOrderHistory();
      });
    } else {
      debugPrint("[EditCheck] CANNOT edit. Deadline passed.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Editing deadline (ending ${DateFormat('MMM d, hh:mm a').format(deadlineForThisOrder)}) has passed.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final DateFormat dateFormat = DateFormat('MMM d, yyyy \'at\' hh:mm a');

    return Scaffold(
      appBar: AppBar(title: const Text('My Order History'), centerTitle: true),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadOrderHistory,
          child: Builder(builder: (context) {
            if (_isLoading && _orders.isEmpty) return const Center(child: CircularProgressIndicator());
            if (_errorMessage != null) return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error, fontSize: 16), textAlign: TextAlign.center)));
            if (_orders.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('You have no past orders yet.', style: theme.textTheme.titleMedium, textAlign: TextAlign.center)));

            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text(order.foodName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // order.canEdit is always true from the model,
                                // the actual check is in _navigateToEditOrder
                                if (order.canEdit)
                                  IconButton(
                                    icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
                                    tooltip: 'Edit Order',
                                    onPressed: _isLoading ? null : () => _navigateToEditOrder(order),
                                  ),
                                if (order.canDelete)
                                  IconButton(
                                    icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                    tooltip: 'Delete Order',
                                    onPressed: _isLoading ? null : () => _deleteOrder(order.id),
                                  )
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Items: ${order.totalQuantity}'),
                        Text('Total: TSh ${order.totalPrice.toStringAsFixed(0)}/=', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        const SizedBox(height: 4),
                        Text('Status: ${order.status.capitalizeFirst()}', style: TextStyle(color: _getStatusColor(order.status, theme))),
                        const SizedBox(height: 4),
                        Text('Ordered: ${dateFormat.format(order.orderTime)}', style: theme.textTheme.bodySmall),
                        if (order.lastEditedAt != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text('Last Edited: ${dateFormat.format(order.lastEditedAt!)}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange.shade700;
      case 'sent': case 'confirmed': return Colors.blue.shade700;
      case 'preparing': return Colors.deepPurple.shade400;
      case 'ready_for_pickup': case 'readyforpickup': return Colors.teal.shade600;
      case 'completed': return Colors.green.shade700;
      case 'cancelled': case 'cancelled_by_user': case 'failed': case 'deleted': return theme.colorScheme.error;
      default: return theme.textTheme.bodyMedium?.color ?? Colors.black54;
    }
  }
}

