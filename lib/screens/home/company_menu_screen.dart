import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/food_model.dart';

class CompanyMenuScreen extends StatefulWidget {
  final String companyId;
  final String companyName;

  const CompanyMenuScreen({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<CompanyMenuScreen> createState() => _CompanyMenuScreenState();
}

class _CompanyMenuScreenState extends State<CompanyMenuScreen> {
  final supabase = Supabase.instance.client;

  List<FoodModel> _menuItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCompanyMenu();
  }

  Future<void> _fetchCompanyMenu() async {
    try {
      final response = await supabase
          .from('foods')
          .select()
          .eq('company_id', widget.companyId);

      if (mounted) {
        setState(() {
          _menuItems =
              (response as List).map((item) => FoodModel.fromMap(item)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Failed to load menu: $e";
        _isLoading = false;
      });
    }
  }

  void _openOrderScreen(FoodModel food) {
    // TODO: Implement navigation to order screen with food details
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Selected: ${food.name}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.companyName} Menu')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _menuItems.isEmpty
          ? const Center(child: Text("No menu items available."))
          : RefreshIndicator(
        onRefresh: _fetchCompanyMenu,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _menuItems.length,
          itemBuilder: (context, index) {
            final food = _menuItems[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                leading: food.imageUrl != null &&
                    food.imageUrl!.isNotEmpty
                    ? Image.network(
                  food.imageUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.fastfood),
                )
                    : const Icon(Icons.fastfood),
                title: Text(food.name),
                subtitle: Text("\$${food.price.toStringAsFixed(2)}"),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _openOrderScreen(food),
              ),
            );
          },
        ),
      ),
    );
  }
}
