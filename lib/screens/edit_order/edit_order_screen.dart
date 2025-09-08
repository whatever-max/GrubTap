// lib/screens/edit_order/edit_order_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // <<< Import for DateFormat
import 'package:grubtap/models/food_model.dart';
// import 'package:grubtap/models/order_model.dart' show ParsedOrderItem; // Not directly needed if using rawOrderItems
import 'package:grubtap/screens/history/order_history_screen.dart' show OrderHistoryDisplayItem;
import 'package:grubtap/utils/string_extensions.dart'; // <<< Import for capitalizeFirst

class EditOrderScreen extends StatefulWidget {
  static const String routeName = '/edit-order';
  final OrderHistoryDisplayItem orderToEdit;

  const EditOrderScreen({super.key, required this.orderToEdit});

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  final supabase = Supabase.instance.client;
  List<FoodModel> _allFoods = [];
  bool _isLoadingFoods = true;
  String? _foodListErrorMessage;
  final TextEditingController _foodDropdownController = TextEditingController();

  FoodModel? _selectedFoodForUpdate;
  int _quantity = 1;
  bool _isProcessingUpdate = false;
  String? _updateErrorMessage;

  @override
  void initState() {
    super.initState();
    debugPrint("[EditOrderScreen] initState for order ID: ${widget.orderToEdit.id}");
    _loadAllFoodsAndPreselect();
  }

  Future<void> _loadAllFoodsAndPreselect() async {
    setState(() {
      _isLoadingFoods = true;
      _foodListErrorMessage = null;
    });

    try {
      final response = await supabase
          .from('foods')
          .select('id, name, price, description, image_url, company_id')
          .order('name', ascending: true);

      if (!mounted) return;

      if (response.isEmpty) {
        _allFoods = [];
        _foodListErrorMessage = "No food items available for selection.";
      } else {
        _allFoods = response
            .map((item) => FoodModel.fromMap(item as Map<String, dynamic>))
            .toList();
        _foodListErrorMessage = null;

        if (widget.orderToEdit.rawOrderItems.isNotEmpty) {
          final firstOriginalItemData = widget.orderToEdit.rawOrderItems.first;
          final String? originalFoodId = firstOriginalItemData['food_id'] as String?;

          if (originalFoodId != null) {
            try {
              _selectedFoodForUpdate = _allFoods.firstWhere(
                    (food) => food.id == originalFoodId,
              );
            } catch (e) { // If firstWhere finds no element
              debugPrint("[EditOrderScreen] Original food ID '$originalFoodId' not found in current food list. Defaulting if possible.");
              if (_allFoods.isNotEmpty) _selectedFoodForUpdate = _allFoods.first;
            }

            if (_selectedFoodForUpdate != null) {
              _foodDropdownController.text = "${_selectedFoodForUpdate!.name} - TSh ${_selectedFoodForUpdate!.price.toStringAsFixed(0)}/=";
              _quantity = (firstOriginalItemData['quantity'] as int?) ?? 1;
            }
          } else if (_allFoods.isNotEmpty) {
            _selectedFoodForUpdate = _allFoods.first;
            _foodDropdownController.text = "${_selectedFoodForUpdate!.name} - TSh ${_selectedFoodForUpdate!.price.toStringAsFixed(0)}/=";
          }
        } else if (_allFoods.isNotEmpty) {
          _selectedFoodForUpdate = _allFoods.first;
          _foodDropdownController.text = "${_selectedFoodForUpdate!.name} - TSh ${_selectedFoodForUpdate!.price.toStringAsFixed(0)}/=";
        }
      }
    } on PostgrestException catch (e) {
      _foodListErrorMessage = 'Failed to load food items: ${e.message}';
      debugPrint("[EditOrderScreen] PostgrestException loading foods: ${e.message}");
    } catch (e) {
      _foodListErrorMessage = 'An unexpected error occurred: ${e.toString()}';
      debugPrint("[EditOrderScreen] Generic error loading foods: ${e.toString()}");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingFoods = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _foodDropdownController.dispose();
    super.dispose();
  }

  Future<void> _updateOrder() async {
    if (_selectedFoodForUpdate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a food item.'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be at least 1.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isProcessingUpdate = true;
      _updateErrorMessage = null;
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception("User not logged in.");

      await supabase
          .from('order_items')
          .delete()
          .eq('order_id', widget.orderToEdit.id);
      debugPrint("[EditOrderScreen] Deleted old order_items for order ID: ${widget.orderToEdit.id}");

      final newOrderItemData = {
        'order_id': widget.orderToEdit.id,
        'food_id': _selectedFoodForUpdate!.id,
        'quantity': _quantity,
        'item_price': _selectedFoodForUpdate!.price,
      };
      await supabase.from('order_items').insert(newOrderItemData);
      debugPrint("[EditOrderScreen] Inserted new order_item: $newOrderItemData");

      // =======================================================================
      // THE ACTUAL FIX IS HERE:
      // Only update fields that exist on the 'orders' table based on your schema.
      // 'quantity' and 'total_price' ARE NOT on the 'orders' table.
      // =======================================================================
      final updatedOrderData = {
        'status': 'sent',
        'food_id': _selectedFoodForUpdate!.id,
        'company_id': _selectedFoodForUpdate!.profileId,
        'last_edited_at': DateTime.now().toUtc().toIso8601String(),
      };
      // =======================================================================

      await supabase
          .from('orders')
          .update(updatedOrderData)
          .eq('id', widget.orderToEdit.id);
      debugPrint("[EditOrderScreen] Updated main orders table for ID: ${widget.orderToEdit.id} with data: $updatedOrderData");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order updated successfully!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } on PostgrestException catch (e) {
      debugPrint("[EditOrderScreen] Supabase error updating order: ${e.message}, code: ${e.code}, details: ${e.details}, hint: ${e.hint}");
      setState(() {
        _updateErrorMessage = "DB Error: ${e.message}. Check logs.";
      });
    } catch (e) {
      debugPrint("[EditOrderScreen] Generic error updating order: $e");
      setState(() {
        _updateErrorMessage = "Error: ${e.toString()}";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingUpdate = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    double cardWidth = MediaQuery.of(context).size.width > 600 ? 500 : double.infinity;

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Order (ID: ...${widget.orderToEdit.id.substring(widget.orderToEdit.id.length - 6)})'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: SizedBox(
              width: cardWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Original Order: ${widget.orderToEdit.foodName}',
                    style: textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    'Time: ${DateFormat('MMM d, hh:mm a').format(widget.orderToEdit.orderTime)} - Status: ${widget.orderToEdit.status.capitalizeFirst()}',
                    style: textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Change to:',
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  if (_isLoadingFoods)
                    const Center(child: CircularProgressIndicator())
                  else if (_foodListErrorMessage != null)
                    Text(_foodListErrorMessage!, style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center)
                  else if (_allFoods.isEmpty)
                      const Text("No food items available to select.", textAlign: TextAlign.center)
                    else
                      DropdownMenu<FoodModel>(
                        controller: _foodDropdownController,
                        requestFocusOnTap: true,
                        label: const Text('Select New Food Item'),
                        expandedInsets: EdgeInsets.zero,
                        initialSelection: _selectedFoodForUpdate,
                        onSelected: (FoodModel? food) {
                          setState(() {
                            _selectedFoodForUpdate = food;
                            if (food != null && food.id != _selectedFoodForUpdate?.id) { // Reset quantity if food changes
                              _quantity = 1;
                            }
                          });
                        },
                        dropdownMenuEntries: _allFoods.map<DropdownMenuEntry<FoodModel>>((FoodModel food) {
                          return DropdownMenuEntry<FoodModel>(
                            value: food,
                            label: "${food.name} - TSh ${food.price.toStringAsFixed(0)}/=",
                          );
                        }).toList(),
                      ),
                  const SizedBox(height: 20),
                  if (_selectedFoodForUpdate != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_circle_outline, color: theme.colorScheme.primary, size: 32),
                          onPressed: _isProcessingUpdate
                              ? null
                              : () {
                            if (_quantity > 1) setState(() => _quantity--);
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('$_quantity', style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline, color: theme.colorScheme.primary, size: 32),
                          onPressed: _isProcessingUpdate
                              ? null
                              : () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        'New Total: TSh ${(_selectedFoodForUpdate!.price * _quantity).toStringAsFixed(0)}/=',
                        style: textTheme.titleLarge?.copyWith(
                            color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_updateErrorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(
                        _updateErrorMessage!,
                        style: TextStyle(color: theme.colorScheme.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ElevatedButton.icon(
                    icon: _isProcessingUpdate ? const SizedBox.shrink() : const Icon(Icons.check_circle_outline),
                    label: _isProcessingUpdate
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Update Order'),
                    onPressed: (_isProcessingUpdate || _selectedFoodForUpdate == null) ? null : _updateOrder,
                    style: theme.elevatedButtonTheme.style,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
