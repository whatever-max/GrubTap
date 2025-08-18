import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/food_model.dart';
import '../../models/company_model.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({Key? key}) : super(key: key);

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        // It's often better to throw a specific error or set an error message
        // rather than a generic Exception if you want to handle it distinctly.
        if (mounted) {
          setState(() {
            _errorMessage = 'User not logged in. Please log in and try again.';
            _isLoading = false;
          });
        }
        return;
      }

      // `select()` now throws a PostgrestException on error directly.
      // The response will be List<Map<String, dynamic>> on success.
      final List<Map<String, dynamic>> data = await supabase
          .from('orders')
          .select('*, foods(*), companies(*)')
          .eq('user_id', user.id)
          .order('order_time', ascending: false);

      // No need to check response.error, the try-catch will handle it.
      // The type of 'data' is already List<Map<String, dynamic>> due to the await.

      // It's good practice to check if the widget is still mounted
      // before calling setState, especially after async operations.
      if (mounted) {
        setState(() {
          _orders = data; // Directly assign, no need for .from(data) if types match
          _isLoading = false;
        });
      }
    } on PostgrestException catch (e) {
      debugPrint('Supabase error loading orders (PostgrestException): ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load order history: ${e.message}';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      // Catching other potential errors (like 'User not logged in' if you threw an Exception)
      debugPrint('Error loading orders (General Exception): $e\n$stackTrace');
      if (mounted) {
        setState(() {
          // You might want a more generic message or one based on the caught error 'e'
          _errorMessage = 'An unexpected error occurred while loading orders.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reorder(Map<String, dynamic> order) async {
    // Check for mounted at the beginning of async methods that update state.
    if (!mounted) return;

    try {
      final foodMap = order['foods'] as Map<String, dynamic>?;
      final companyMap = order['companies'] as Map<String, dynamic>?;

      if (foodMap == null || companyMap == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order data incomplete: cannot reorder.')),
        );
        return;
      }

      final food = FoodModel.fromMap(foodMap);
      final company = CompanyModel.fromMap(companyMap);
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in. Cannot reorder.')),
        );
        return;
      }

      await supabase.from('orders').insert({
        'user_id': userId,
        'food_id': food.id,
        'company_id': company.id,
        'order_time': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed again!')),
        );
        _loadOrders(); // Refresh the order list
      }
    } on PostgrestException catch (e) {
      debugPrint('Error reordering (PostgrestException): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reorder: ${e.message}')),
        );
      }
    } catch (e) {
      debugPrint('Error reordering (General Exception): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred during reorder.')),
        );
      }
    }
  }

  Future<void> _addToFavorites(Map<String, dynamic> order) async {
    if (!mounted) return;

    try {
      final foodMap = order['foods'] as Map<String, dynamic>?;

      if (foodMap == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot add to favorites: Missing food data.')),
        );
        return;
      }

      final food = FoodModel.fromMap(foodMap);
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in. Cannot add to favorites.')),
        );
        return;
      }

      await supabase.from('favorites').insert({
        'user_id': userId,
        'food_id': food.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to favorites!')),
        );
      }
    } on PostgrestException catch (e) {
      debugPrint('Error adding to favorites (PostgrestException): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to favorites: ${e.message}')),
        );
      }
    } catch (e) {
      debugPrint('Error adding to favorites (General Exception): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred while adding to favorites.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Access theme for consistent styling

    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
        // Consider theming the AppBar if you have a global theme
        // backgroundColor: theme.colorScheme.primary,
        // foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: _buildBodyContent(theme),
    );
  }

  Widget _buildBodyContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column( // Added Column for better layout of error message + retry button
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: _loadOrders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                ),
              )
            ],
          ),
        ),
      );
    }

    if (_orders.isEmpty) {
      return Center(
        child: Column( // Using Column for a slightly richer empty state
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 60, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6)),
            const SizedBox(height: 16),
            Text(
              'No orders found.',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              'Looks like you haven\'t placed any orders yet!',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8.0), // Add some padding around the list
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];

        // Gracefully handle potentially missing nested data
        final foodMap = order['foods'] is Map<String, dynamic>
            ? order['foods'] as Map<String, dynamic>
            : null;
        final companyMap = order['companies'] is Map<String, dynamic>
            ? order['companies'] as Map<String, dynamic>
            : null;

        if (foodMap == null || companyMap == null) {
          // Log this situation for debugging, as it indicates data integrity issues
          debugPrint('Incomplete order data at index $index: $order');
          return Card(
            color: theme.colorScheme.errorContainer.withOpacity(0.5),
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: ListTile(
              leading: Icon(Icons.warning_amber_rounded, color: theme.colorScheme.onErrorContainer),
              title: Text("Incomplete Order Data", style: TextStyle(color: theme.colorScheme.onErrorContainer)),
              subtitle: Text("This order cannot be fully displayed.", style: TextStyle(color: theme.colorScheme.onErrorContainer.withOpacity(0.8))),
            ),
          );
        }

        FoodModel food;
        CompanyModel company;
        try {
          food = FoodModel.fromMap(foodMap);
          company = CompanyModel.fromMap(companyMap);
        } catch (e) {
          debugPrint('Error parsing FoodModel or CompanyModel for order at index $index: $e');
          return Card(
            color: theme.colorScheme.errorContainer.withOpacity(0.5),
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: ListTile(
              leading: Icon(Icons.sync_problem_outlined, color: theme.colorScheme.onErrorContainer),
              title: Text("Data Parsing Error", style: TextStyle(color: theme.colorScheme.onErrorContainer)),
              subtitle: Text("Could not parse order details.", style: TextStyle(color: theme.colorScheme.onErrorContainer.withOpacity(0.8))),
            ),
          );
        }


        final orderTimeStr = order['order_time'] as String? ?? '';
        final orderTime = DateTime.tryParse(orderTimeStr)?.toLocal();

        final formattedTime = orderTime != null
            ? '${orderTime.day.toString().padLeft(2, '0')}/${orderTime.month.toString().padLeft(2, '0')}/${orderTime.year} ${orderTime.hour.toString().padLeft(2, '0')}:${orderTime.minute.toString().padLeft(2, '0')}'
            : 'Unknown time';

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 2, // Add some elevation for a nicer look
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // Rounded corners
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            title: Text(food.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500)),
            subtitle: Text(
              '${company.name} • \$${food.price.toStringAsFixed(2)}\nOrdered at $formattedTime',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            isThreeLine: true,
            trailing: Wrap(
              spacing: 0, // Let IconButton manage its own padding
              children: [
                IconButton(
                  icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
                  tooltip: 'Reorder',
                  onPressed: () => _reorder(order),
                ),
                IconButton(
                  icon: Icon(Icons.favorite_border, color: theme.colorScheme.secondary),
                  tooltip: 'Add to Favorites',
                  onPressed: () => _addToFavorites(order),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
