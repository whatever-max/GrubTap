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
  bool _isLoading = true; // Added for loading state
  String? _errorMessage; // Added for error messages

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
      // The modern .select() directly returns the data or throws PostgrestException on error
      final List<Map<String, dynamic>> data = await supabase
          .from('orders')
          .select<List<Map<String, dynamic>>>('*, foods (*), companies (*)') // Specify expected return type
          .gte('order_time', cutoff);

      // No explicit .execute() needed here as .select itself executes when awaited.

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
      if (mounted) { // mounted check good practice before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching orders: ${error.message}')),
        );
      }
    } catch (error) { // Catch any other unexpected errors
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
    // Ensure 'food' and 'company' keys exist and are not null
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
        // Assuming your 'orders' table directly references 'food_id' and 'company_id'
        // And that 'foods' and 'companies' in your select query return single objects not lists
        'food_id': ord['foods']['id'],
        'company_id': ord['companies']['id'],
        // 'order_time': DateTime.now().toIso8601String(), // You might want to set a new order time
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order placed again!')));
        _loadActiveOrders(); // Refresh list after reordering
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
        'food_id': ord['foods']['id'], // Changed from ord['food']['id'] to ord['foods']['id']
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
          ? Center(child: Text(_errorMessage!, textAlign: TextAlign.center))
          : _activeOrders.isEmpty
          ? const Center(child: Text('No active orders found in the last 5 hours.'))
          : ListView.builder(
        itemCount: _activeOrders.length,
        itemBuilder: (context, i) {
          final ord = _activeOrders[i];
          // Adjust based on your actual Supabase relationship naming for foods and companies
          // If 'foods' and 'companies' are the direct map objects from the select:
          if (ord['foods'] == null || ord['companies'] == null) {
            return const ListTile(title: Text("Error: Incomplete order data"));
          }
          final food = FoodModel.fromMap(ord['foods'] as Map<String, dynamic>);
          final company = CompanyModel.fromMap(ord['companies'] as Map<String, dynamic>);

          return ListTile(
            title: Text(food.name),
            subtitle: Text('${company.name} • \$${food.price.toStringAsFixed(2)}'),
            trailing: Wrap(
              spacing: 8, // Reduced spacing a bit
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Reorder',
                  onPressed: () => _reorder(ord),
                ),
                IconButton(
                  icon: const Icon(Icons.favorite_border), // Use border for non-favorited
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
