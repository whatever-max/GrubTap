// lib/screens/history/order_history_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:grubtap/utils/string_extensions.dart';
// Model for displaying order history items (keep your existing model)
class OrderHistoryDisplayItem {
  // ... (your existing OrderHistoryDisplayItem model code) ...
  final String id;
  final String foodName;
  final double totalPrice;
  final int totalQuantity;
  final String status;
  final DateTime orderTime;
  final bool canDelete;

  OrderHistoryDisplayItem({
    required this.id,
    required this.foodName,
    required this.totalPrice,
    required this.totalQuantity,
    required this.status,
    required this.orderTime,
    required this.canDelete,
  });

  factory OrderHistoryDisplayItem.fromMap(Map<String, dynamic> map) {
    DateTime orderDateTime = DateTime.parse(map['order_time'] as String).toLocal();
    bool isDeletable = false;

    final deletableStatuses = ['completed', 'cancelled', 'failed', 'deleted'];
    if (deletableStatuses.contains(map['status'].toString().toLowerCase()) &&
        DateTime.now().difference(orderDateTime).inHours >= 24) {
      isDeletable = true;
    }

    String currentFoodName = 'N/A'; // Default

    if (map['foods'] != null && map['foods']['name'] != null) {
      currentFoodName = map['foods']['name'] as String;
    }

    double calculatedTotalPrice = 0.0;
    int calculatedTotalQuantity = 0;
    List<String> distinctFoodNamesInOrder = [];

    final orderItems = map['order_items'] as List<dynamic>? ?? [];
    if (orderItems.isNotEmpty) {
      for (var item in orderItems) {
        final itemMap = item as Map<String, dynamic>;
        final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
        final itemPrice = (itemMap['item_price'] as num?)?.toDouble() ?? 0.0;
        calculatedTotalPrice += quantity * itemPrice;
        calculatedTotalQuantity += quantity;

        if (itemMap['foods'] != null && itemMap['foods']['name'] != null) {
          String itemName = itemMap['foods']['name'] as String;
          if (!distinctFoodNamesInOrder.contains(itemName)) {
            distinctFoodNamesInOrder.add(itemName);
          }
        }
      }

      if ((currentFoodName == 'N/A' || map['foods'] == null || map['foods']['name'] == null) && distinctFoodNamesInOrder.isNotEmpty) {
        currentFoodName = distinctFoodNamesInOrder.first;
        if (distinctFoodNamesInOrder.length > 1) {
          currentFoodName += " & more";
        }
      }
    } else if (currentFoodName == 'N/A') {
      currentFoodName = "Order details missing";
    }
    if (calculatedTotalQuantity == 0 && currentFoodName != 'N/A' && currentFoodName != "Order details missing" && orderItems.isEmpty) {
      calculatedTotalQuantity = 1;
    }


    return OrderHistoryDisplayItem(
      id: map['id'].toString(),
      foodName: currentFoodName,
      totalPrice: calculatedTotalPrice,
      totalQuantity: calculatedTotalQuantity,
      status: map['status'] as String? ?? 'Unknown',
      orderTime: orderDateTime,
      canDelete: isDeletable,
    );
  }
}


class OrderHistoryScreen extends StatefulWidget {
  static const String routeName = '/order-history'; // Standard for routing

  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  // ... (keep your existing _OrderHistoryScreenState code) ...
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        if (mounted) {
          setState(() {
            _errorMessage = "User not logged in. Cannot fetch order history.";
            _isLoading = false;
          });
        }
        return;
      }

      final response = await supabase
          .from('orders')
          .select('''
            id,
            status,
            order_time,
            foods (name), 
            order_items (
              quantity,
              item_price,
              foods (name) 
            )
          ''')
          .eq('user_id', userId)
          .neq('status', 'archived')
          .order('order_time', ascending: false);

      if (!mounted) return;

      _orders = response
          .map((item) => OrderHistoryDisplayItem.fromMap(item as Map<String, dynamic>))
          .toList();

      setState(() {
        _isLoading = false;
      });

    } on PostgrestException catch (e) {
      debugPrint("OrderHistoryScreen: Supabase Error loading history: ${e.code} - ${e.message}");
      if (!mounted) return;
      setState(() {
        _errorMessage = "Failed to load order history: ${e.message}";
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("OrderHistoryScreen: Generic error loading history: $e");
      if (!mounted) return;
      setState(() {
        _errorMessage = "An unexpected error occurred: ${e.toString()}";
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteOrder(String orderId) async {
    final confirmDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to mark this order as deleted? This action might be irreversible depending on system setup.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('Delete'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmDelete != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      await supabase
          .from('orders')
          .update({'status': 'deleted'})
          .eq('id', orderId)
          .eq('user_id', supabase.auth.currentUser!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order marked as deleted.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadOrderHistory();
      }
    } on PostgrestException catch (e) {
      debugPrint("OrderHistoryScreen: Supabase Error deleting order: ${e.message}");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete order: ${e.message}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } catch (e) {
      debugPrint("OrderHistoryScreen: Generic error deleting order: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An error occurred: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final DateFormat dateFormat = DateFormat('MMM d, yyyy \'at\' hh:mm a');
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Order History'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadOrderHistory,
          child: Builder(
            builder: (context) {
              if (_isLoading && _orders.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (_errorMessage != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (_orders.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'You have no past orders yet.',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  final order = _orders[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  order.foodName,
                                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (order.canDelete)
                                IconButton(
                                  icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                  tooltip: 'Delete Order',
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                  visualDensity: VisualDensity.compact,
                                  onPressed: _isLoading ? null : () => _deleteOrder(order.id),
                                )
                              else
                                const SizedBox(width: 48, height: 48),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text('Items: ${order.totalQuantity}'),
                          Text(
                              'Total: TSh${order.totalPrice.toStringAsFixed(0)}/=',
                              style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)
                          ),
                          const SizedBox(height: 4),
                          Text('Status: ${order.status.capitalizeFirst()}', style: TextStyle(color: _getStatusColor(order.status, theme))),
                          const SizedBox(height: 4),
                          Text('Ordered: ${dateFormat.format(order.orderTime)}', style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status, ThemeData theme) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.shade700;
      case 'sent':
      case 'confirmed':
        return Colors.blue.shade700;
      case 'processing':
        return Colors.deepPurple.shade400;
      case 'completed':
        return Colors.green.shade700;
      case 'cancelled':
      case 'failed':
      case 'deleted':
        return theme.colorScheme.error;
      default:
        return theme.textTheme.bodyMedium?.color ?? Colors.black54;
    }
  }
}


