// lib/screens/company/company_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:grubtap/utils/string_extensions.dart';
// Models (can be moved to a separate file if preferred)
class CompanyOrderDisplayItem {
  final String orderId;
  final String customerUsername;
  final String? customerPhone;
  final DateTime orderTime;
  final String status;
  final List<CompanyOrderItemDetail> items;
  final double totalOrderAmount;
  final bool canBeDeleted;

  CompanyOrderDisplayItem({
    required this.orderId,
    required this.customerUsername,
    this.customerPhone,
    required this.orderTime,
    required this.status,
    required this.items,
    required this.totalOrderAmount,
    required this.canBeDeleted,
  });
}

class CompanyOrderItemDetail {
  final String foodName;
  final int quantity;
  final double itemPrice;
  final double totalItemAmount;

  CompanyOrderItemDetail({
    required this.foodName,
    required this.quantity,
    required this.itemPrice,
    required this.totalItemAmount,
  });
}
// End Models

class CompanyOrdersScreen extends StatefulWidget {
  static const String routeName = '/company-view-orders';

  const CompanyOrdersScreen({super.key});

  @override
  State<CompanyOrdersScreen> createState() => _CompanyOrdersScreenState();
}

class _CompanyOrdersScreenState extends State<CompanyOrdersScreen> {
  final supabase = Supabase.instance.client;
  String? _companyId;
  List<CompanyOrderDisplayItem> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  final DateFormat _dateFormat = DateFormat('MMM d, yyyy \'at\' hh:mm a');

  @override
  void initState() {
    super.initState();
    _fetchCompanyIdAndThenOrders();
  }

  Future<void> _fetchCompanyIdAndThenOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _orders = [];
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception("User not authenticated. Cannot view orders.");
      }

      final companyResponse = await supabase
          .from('companies')
          .select('id')
          .eq('created_by', userId)
          .maybeSingle();

      if (!mounted) return;
      if (companyResponse == null) {
        throw Exception("NO_COMPANY_PROFILE");
      }
      _companyId = companyResponse['id'] as String?;
      if (_companyId == null || _companyId!.isEmpty) {
        throw Exception("Could not determine Company Profile ID.");
      }
      debugPrint("[CompanyOrdersScreen] Company ID: $_companyId");

      final ordersResponse = await supabase
          .from('orders')
          .select('''
            order_id: id, 
            order_time,
            status,
            customer: user_id ( username, phone ), 
            order_items (
              quantity,
              item_price,
              food: food_id ( name )
            )
          ''')
          .eq('company_id', _companyId!)
          .eq('status', 'sent')
          .order('order_time', ascending: false);

      if (!mounted) return;

      final List<CompanyOrderDisplayItem> fetchedOrders = [];
      final now = DateTime.now();

      for (var orderData in ordersResponse) {
        final orderMap = orderData as Map<String, dynamic>;
        final customerData = orderMap['customer'] as Map<String, dynamic>?;
        final String customerUsername = customerData?['username'] as String? ?? 'Unknown User';
        final String? customerPhone = customerData?['phone'] as String?;
        final List<CompanyOrderItemDetail> itemDetails = [];
        double currentOrderTotal = 0;
        final itemsList = orderMap['order_items'] as List<dynamic>? ?? [];

        for (var item in itemsList) {
          final itemMap = item as Map<String, dynamic>;
          final foodData = itemMap['food'] as Map<String, dynamic>?;
          final foodName = foodData?['name'] as String? ?? 'Unknown Food';
          final quantity = (itemMap['quantity'] as num?)?.toInt() ?? 0;
          final itemPrice = (itemMap['item_price'] as num?)?.toDouble() ?? 0.0;
          final totalItemAmount = quantity * itemPrice;

          itemDetails.add(CompanyOrderItemDetail(
            foodName: foodName,
            quantity: quantity,
            itemPrice: itemPrice,
            totalItemAmount: totalItemAmount,
          ));
          currentOrderTotal += totalItemAmount;
        }

        final orderTime = DateTime.parse(orderMap['order_time'] as String).toLocal();
        final bool canBeDeleted = orderMap['status'] == 'sent' && now.difference(orderTime).inHours >= 24;

        fetchedOrders.add(CompanyOrderDisplayItem(
          orderId: orderMap['order_id'].toString(),
          customerUsername: customerUsername,
          customerPhone: customerPhone,
          orderTime: orderTime,
          status: orderMap['status'] as String,
          items: itemDetails,
          totalOrderAmount: currentOrderTotal,
          canBeDeleted: canBeDeleted,
        ));
      }
      _orders = fetchedOrders;
      debugPrint("[CompanyOrdersScreen] Fetched ${_orders.length} 'sent' orders.");

    } catch (e) {
      if (mounted) {
        String displayError;
        if (e.toString().contains("NO_COMPANY_PROFILE")) {
          displayError = "No company profile found linked to your account. Cannot fetch orders.";
        } else if (e is PostgrestException) {
          displayError = "Database error fetching orders: ${e.message}";
        } else if (e.toString().contains("User not authenticated")) {
          displayError = "User not authenticated. Please log in again.";
        } else {
          displayError = "Failed to load orders: ${e.toString()}";
        }
        setState(() {
          _errorMessage = displayError;
        });
        debugPrint("[CompanyOrdersScreen] Error: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _archiveOrder(String orderId) async { // Renamed for clarity
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Order'),
        content: const Text('Are you sure you want to archive this order? It will be removed from this list and will no longer be considered an active incoming order.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await supabase
            .from('orders')
            .update({'status': 'archived_by_company'})
            .eq('id', orderId)
            .eq('company_id', _companyId!);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order archived successfully.'), backgroundColor: Colors.orangeAccent),
        );
        _fetchCompanyIdAndThenOrders();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error archiving order: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
        );
        debugPrint("[CompanyOrdersScreen] Error archiving order: $e");
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDailySummary() {
    if (_orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders available to summarize.')),
      );
      return;
    }

    int totalOrders = _orders.length;
    double grandTotalAmount = 0;
    Map<String, ({int quantity, double totalAmount})> foodSummary = {};

    for (var order in _orders) {
      grandTotalAmount += order.totalOrderAmount;
      for (var item in order.items) {
        final currentFood = foodSummary[item.foodName];
        foodSummary[item.foodName] = (
        quantity: (currentFood?.quantity ?? 0) + item.quantity,
        totalAmount: (currentFood?.totalAmount ?? 0) + item.totalItemAmount
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sent Orders Summary'), // "Today's" might be misleading if not filtering by date
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('Total Orders Received: $totalOrders', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Grand Total Amount: TSh ${grandTotalAmount.toStringAsFixed(0)}/=', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Per Food Summary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (foodSummary.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('No individual items found in these orders to summarize.'),
                )
              else
                ...foodSummary.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                      Text('  Total Quantity: ${entry.value.quantity}'),
                      Text('  Total from this food: TSh ${entry.value.totalAmount.toStringAsFixed(0)}/='),
                    ],
                  ),
                )),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget bodyContent;

    if (_isLoading && _orders.isEmpty) {
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      bool isCriticalError = _errorMessage!.contains("No company profile found") ||
          _errorMessage!.contains("User not authenticated");
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 50),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              if (!isCriticalError)
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  onPressed: _fetchCompanyIdAndThenOrders,
                )
            ],
          ),
        ),
      );
    } else if (_orders.isEmpty) {
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long_outlined, size: 60, color: theme.colorScheme.secondary),
              const SizedBox(height: 16),
              const Text(
                "No incoming 'sent' orders at the moment.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                "New orders will appear here once customers place them.",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    } else {
      bodyContent = ListView.builder(
        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            elevation: 3,
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
                          'Order ID: ${order.orderId.substring(0, 8)}...',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                      if (order.canBeDeleted)
                        IconButton(
                          icon: Icon(Icons.archive_outlined, color: Colors.orange.shade700, size: 20),
                          tooltip: 'Archive this Order',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => _archiveOrder(order.orderId), // Updated call
                        )
                    ],
                  ),
                  const Divider(),
                  Text('Customer: ${order.customerUsername}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  if (order.customerPhone != null && order.customerPhone!.isNotEmpty)
                    Text('Phone: ${order.customerPhone}'),
                  Text('Time: ${_dateFormat.format(order.orderTime)}'),
                  Text('Status: ${order.status.capitalizeFirst()}', style: TextStyle(color: theme.colorScheme.secondary, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 8),
                  Text('Items:', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text('${item.quantity} x ${item.foodName}')),
                        Text('TSh ${item.totalItemAmount.toStringAsFixed(0)}/='),
                      ],
                    ),
                  )).toList(),
                  const Divider(height: 16, thickness: 0.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('Order Total: ', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text(
                        'TSh ${order.totalOrderAmount.toStringAsFixed(0)}/=',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incoming Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize_outlined),
            tooltip: 'View Orders Summary',
            onPressed: (_isLoading || _orders.isEmpty) ? null : _showDailySummary,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCompanyIdAndThenOrders,
        child: bodyContent,
      ),
    );
  }
}

