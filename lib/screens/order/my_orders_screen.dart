import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({Key? key}) : super(key: key);

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _error;
  Set<int> _favoriteFoodIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final cutoffDate = DateTime.now().toUtc().subtract(const Duration(hours: 5)).toIso8601String();

      // Fetch recent orders filtered on server side
      final ordersData = await supabase
          .from('orders')
          .select('id, created_at, status, items, food_id')
          .eq('user_id', user.id)
          .gte('created_at', cutoffDate)
          .order('created_at', ascending: false);

      // Fetch user's favorite food IDs
      final favsData = await supabase
          .from('favorites')
          .select('food_id')
          .eq('user_id', user.id);

      setState(() {
        _orders = List<Map<String, dynamic>>.from(ordersData);
        _favoriteFoodIds = favsData != null
            ? Set<int>.from(favsData.map((f) => f['food_id'] as int))
            : {};
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() {
        _error = 'Failed to load your orders.';
        _isLoading = false;
      });
    }
  }

  bool canPlaceOrder() {
    final now = DateTime.now();
    final startBlock = TimeOfDay(hour: 10, minute: 31);
    final endBlock = TimeOfDay(hour: 15, minute: 30);
    final nowTod = TimeOfDay(hour: now.hour, minute: now.minute);

    bool isBlocked = (nowTod.hour > startBlock.hour ||
        (nowTod.hour == startBlock.hour && nowTod.minute >= startBlock.minute)) &&
        (nowTod.hour < endBlock.hour ||
            (nowTod.hour == endBlock.hour && nowTod.minute <= endBlock.minute));

    return !isBlocked;
  }

  Future<void> _toggleFavorite(int foodId, bool currentlyFavorite) async {
    final userId = supabase.auth.currentUser!.id;

    try {
      if (currentlyFavorite) {
        // Remove favorite
        await supabase
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('food_id', foodId);
        setState(() {
          _favoriteFoodIds.remove(foodId);
        });
      } else {
        // Add favorite
        await supabase.from('favorites').insert({
          'user_id': userId,
          'food_id': foodId,
        });
        setState(() {
          _favoriteFoodIds.add(foodId);
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(currentlyFavorite ? 'Removed from Favorites' : 'Added to Favorites'),
        ));
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update favorites: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Orders (Last 5h)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh Orders',
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _orders.isEmpty
          ? const Center(child: Text('No orders in the last 5 hours.'))
          : ListView.builder(
        itemCount: _orders.length,
        itemBuilder: (context, index) {
          final order = _orders[index];
          final createdAt = DateTime.parse(order['created_at']).toLocal();
          final formattedTime = TimeOfDay.fromDateTime(createdAt).format(context);
          final status = order['status'] ?? 'Pending';
          final foodId = order['food_id'] as int? ?? 0;
          final isFavorite = _favoriteFoodIds.contains(foodId);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: ListTile(
              title: Text('Order #${order['id'].toString().substring(0, 6)}'),
              subtitle: Text('Placed at $formattedTime\nStatus: $status'),
              trailing: IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : null,
                ),
                tooltip: isFavorite ? 'Remove from favorites' : 'Add to favorites',
                onPressed: () => _toggleFavorite(foodId, isFavorite),
              ),
              onTap: () {
                if (!canPlaceOrder()) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Ordering is disabled between 10:31 AM and 3:30 PM.'),
                  ));
                }
                // You can add more tap functionality here
              },
            ),
          );
        },
      ),
    );
  }
}
