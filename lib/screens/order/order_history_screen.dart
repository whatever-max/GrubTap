// lib/screens/order/order_history_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/food_model.dart';
import '../../models/company_model.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _activeOrders = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadActiveOrders();
  }

  Future<void> _loadActiveOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final cutoff = DateTime.now().subtract(const Duration(hours: 5)).toUtc().toIso8601String();
      // Corrected: Removed explicit type argument from .select()
      // The .select() directly returns List<Map<String, dynamic>> or throws PostgrestException.
      final List<Map<String, dynamic>> data = await supabase
          .from('orders')
          .select('*, foods (*), companies (*)') // Corrected (select string is fine)
          .gte('order_time', cutoff);

      setState(() {
        _activeOrders = data;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      debugPrint('Error fetching orders: ${error.message}');
      setState(() {
        _errorMessage = 'Failed to load orders: ${error.message}';
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching orders: ${error.message}')),
        );
      }
    } catch (error) {
      debugPrint('Unexpected error fetching orders: $error');
      setState(() {
        _errorMessage = 'An unexpected error occurred.';
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred while fetching orders.')),
        );
      }
    }
  }

  Future<void> _reorder(Map<String, dynamic> ord) async {
    if (ord['foods'] == null || ord['companies'] == null) {
      debugPrint('Error reordering: Food or Company data is missing from the order object.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not reorder: Missing item details.')));
      }
      return;
    }

    try {
      await supabase.from('orders').insert({
        'user_id': supabase.auth.currentUser!.id,
        'food_id': ord['foods']['id'],
        'company_id': ord['companies']['id'],
        // 'order_time': DateTime.now().toIso8601String(), // Uncomment if you want to set a new order time
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order placed again!')));
        _loadActiveOrders();
      }
    } on PostgrestException catch (error) {
      debugPrint('Error reordering: ${error.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reorder: ${error.message}')),
        );
      }
    } catch (error) {
      debugPrint('Unexpected error reordering: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred during reorder.')),
        );
      }
    }
  }

  Future<void> _addToFavorites(Map<String, dynamic> ord) async {
    if (ord['foods'] == null) {
      debugPrint('Error adding to favorites: Food data is missing.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not add to favorites: Missing item details.')),
        );
      }
      return;
    }
    try {
      await supabase.from('favorites').insert({
        'user_id': supabase.auth.currentUser!.id,
        'food_id': ord['foods']['id'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to Favorites!')));
      }
    } on PostgrestException catch (error) {
      debugPrint('Error adding to favorites: ${error.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to favorites: ${error.message}')),
        );
      }
    } catch (error) {
      debugPrint('Unexpected error adding to favorites: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An unexpected error occurred while adding to favorites.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders (Last 5h)')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
      ))
          : _activeOrders.isEmpty
          ? const Center(child: Text('No active orders found in the last 5 hours.'))
          : ListView.builder(
        itemCount: _activeOrders.length,
        itemBuilder: (context, i) {
          final ord = _activeOrders[i];

          if (ord['foods'] == null || ord['companies'] == null) {
            // Log this for debugging, this indicates an issue with data consistency or query
            debugPrint("Incomplete order data at index $i: $ord");
            return Card( // Show a more noticeable error in the UI for this item
              color: Colors.red[100],
              margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              child: const ListTile(
                leading: Icon(Icons.error_outline, color: Colors.red),
                title: Text("Error: Incomplete order data"),
                subtitle: Text("This order item cannot be displayed correctly."),
              ),
            );
          }
          final food = FoodModel.fromMap(ord['foods'] as Map<String, dynamic>);
          final company = CompanyModel.fromMap(ord['companies'] as Map<String, dynamic>);

          return ListTile(
            title: Text(food.name),
            subtitle: Text('${company.name} • \$${food.price.toStringAsFixed(2)}'),
            trailing: Wrap(
              spacing: 8,
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reorder',
                  onPressed: () => _reorder(ord),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite_border),
                  tooltip: 'Add to Favorites',
                  onPressed: () => _addToFavorites(ord),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
