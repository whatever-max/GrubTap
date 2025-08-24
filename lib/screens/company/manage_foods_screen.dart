// lib/screens/company/manage_foods_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/food_model.dart';
import 'package:flutter/services.dart'; // For TextInputFormatters

class ManageFoodsScreen extends StatefulWidget {
  static const String routeName = '/company-manage-foods';

  const ManageFoodsScreen({super.key});

  @override
  State<ManageFoodsScreen> createState() => _ManageFoodsScreenState();
}

class _ManageFoodsScreenState extends State<ManageFoodsScreen> {
  final supabase = Supabase.instance.client;
  String? _companyId;
  List<FoodModel> _foods = [];
  bool _isLoading = true;
  String? _errorMessage;

  // GlobalKey for the Add/Edit Food Form
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  bool _isSavingFood = false;


  @override
  void initState() {
    super.initState();
    _fetchCompanyIdAndThenFoods();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _fetchCompanyIdAndThenFoods() async {
    // ... (Keep your existing _fetchCompanyIdAndThenFoods method - it's good) ...
    // Ensure this method clears _foods and sets _isLoading = true at the start
    // and _isLoading = false in the finally block.
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _foods = [];
    });

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception("User not authenticated. Cannot manage foods.");
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
        throw Exception("Could not determine your Company Profile ID even after fetching. Please check profile setup.");
      }
      debugPrint("[ManageFoodsScreen] Company ID successfully fetched: $_companyId");

      final foodResponse = await supabase
          .from('foods')
          .select('id, name, price, description, image_url, company_id')
          .eq('company_id', _companyId!)
          .order('name', ascending: true);

      if (!mounted) return;
      _foods = foodResponse.map((data) => FoodModel.fromMap(data)).toList();
      debugPrint("[ManageFoodsScreen] Fetched ${_foods.length} food items for company_id: $_companyId");

    } catch (e) {
      if (mounted) {
        String displayError;
        if (e.toString().contains("NO_COMPANY_PROFILE")) {
          displayError = "No company profile found linked to your account. Please ensure your company profile is set up, or contact support.";
        } else if (e is PostgrestException) {
          displayError = "Database error: ${e.message}. Please try again or contact support.";
        } else if (e.toString().contains("User not authenticated")) {
          displayError = "User not authenticated. Please log in again.";
        } else {
          displayError = "Failed to load your menu: ${e.toString()}. Please try again.";
        }
        setState(() {
          _errorMessage = displayError;
        });
        debugPrint("[ManageFoodsScreen] Error: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _clearFormControllers() {
    _nameController.clear();
    _priceController.clear();
    _descriptionController.clear();
    _imageUrlController.clear();
  }

  Future<void> _showAddEditFoodDialog({FoodModel? foodToEdit}) async {
    if (_companyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot manage food: Company ID not available.')),
      );
      return;
    }

    final bool isEditing = foodToEdit != null;
    if (isEditing) {
      _nameController.text = foodToEdit.name;
      _priceController.text = foodToEdit.price.toStringAsFixed(0); // Assuming no decimal for Tanzanian Shillings display
      _descriptionController.text = foodToEdit.description ?? '';
      _imageUrlController.text = foodToEdit.imageUrl ?? '';
    } else {
      _clearFormControllers(); // Ensure form is clear for adding new
    }

    return showDialog<void>(
      context: context,
      barrierDismissible: !_isSavingFood, // Prevent dismissal while saving
      builder: (BuildContext dialogContext) {
        // Use a StatefulWidget for the dialog content to manage its own state for _isSavingFood
        return StatefulBuilder(
            builder: (stfContext, stfSetState) {
              return AlertDialog(
                title: Text(isEditing ? 'Edit Food Item' : 'Add New Food Item'),
                content: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(labelText: 'Food Name', hintText: 'e.g., Chips Mayai'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a food name.';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _priceController,
                          decoration: const InputDecoration(labelText: 'Price (TSh)', hintText: 'e.g., 3000'),
                          keyboardType: const TextInputType.numberWithOptions(decimal: false),
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a price.';
                            }
                            if (double.tryParse(value) == null || double.parse(value) <= 0) {
                              return 'Please enter a valid positive price.';
                            }
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(labelText: 'Description (Optional)', hintText: 'e.g., Special chips with two eggs'),
                          maxLines: 2,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _imageUrlController,
                          decoration: const InputDecoration(labelText: 'Image URL (Optional)', hintText: 'https://example.com/image.png'),
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.done,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: <Widget>[
                  TextButton(
                    onPressed: _isSavingFood ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _isSavingFood ? null : () async {
                      if (_formKey.currentState!.validate()) {
                        stfSetState(() => _isSavingFood = true);
                        try {
                          final foodData = {
                            'name': _nameController.text.trim(),
                            'price': double.parse(_priceController.text),
                            'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                            'image_url': _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
                            'company_id': _companyId,
                          };

                          if (isEditing) {
                            // Update existing food
                            await supabase.from('foods').update(foodData).eq('id', foodToEdit.id).eq('company_id', _companyId!); // Ensure company owns it
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${foodData['name']}" updated successfully!'), backgroundColor: Colors.green));
                          } else {
                            // Add new food
                            await supabase.from('foods').insert(foodData);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${foodData['name']}" added successfully!'), backgroundColor: Colors.green));
                          }

                          if (mounted) Navigator.of(dialogContext).pop(); // Close dialog
                          _fetchCompanyIdAndThenFoods(); // Refresh the list
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error saving food: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
                            );
                          }
                          debugPrint("[ManageFoodsScreen] Error saving food: $e");
                        } finally {
                          // Check mounted again before calling stfSetState from dialog context
                          if (Navigator.of(dialogContext).canPop()) { // Check if dialog is still active
                            stfSetState(() => _isSavingFood = false);
                          } else if (mounted) { // Fallback if dialog somehow closed but screen is active
                            setState(() => _isSavingFood = false); // Manage screen's _isSavingFood if needed, though primarily for dialog
                          }
                        }
                      }
                    },
                    child: _isSavingFood
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(isEditing ? 'Save Changes' : 'Add Food'),
                  ),
                ],
              );
            }
        );
      },
    ).then((_) {
      // Called when the dialog is dismissed.
      // Reset _isSavingFood at the screen level if it was managed there,
      // though primarily the dialog's StatefulBuilder manages it during its lifecycle.
      if (mounted && _isSavingFood) {
        setState(() => _isSavingFood = false);
      }
      _clearFormControllers(); // Always clear controllers when dialog closes
    });
  }

  // --- Edit and Delete Methods ---
  void _navigateToEditFood(FoodModel food) {
    _showAddEditFoodDialog(foodToEdit: food);
  }

  Future<void> _deleteFood(FoodModel food) async {
    // ... (Keep your existing _deleteFood method, it's good) ...
    if (_companyId == null) return;
    debugPrint("[ManageFoodsScreen] Attempting to delete food: ${food.name}");

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${food.name}"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Use a local loading state for this specific operation if preferred
      // For simplicity here, we'll re-use the main _isLoading, but set it specifically.
      setState(() => _isLoading = true);
      try {
        await supabase
            .from('foods')
            .delete()
            .eq('id', food.id)
            .eq('company_id', _companyId!);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${food.name}" deleted successfully'), backgroundColor: Colors.green),
        );
        _fetchCompanyIdAndThenFoods(); // Refresh list, which will also set _isLoading appropriately
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting food: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
        );
        debugPrint("[ManageFoodsScreen] Error deleting food: $e");
        // If fetch doesn't run due to error, ensure loading is false
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // ... (Your existing build method for bodyContent and Scaffold structure) ...
    // The main change is calling _showAddEditFoodDialog from the FAB's onPressed.
    final theme = Theme.of(context);

    Widget bodyContent;
    if (_isLoading && _foods.isEmpty && !_isSavingFood) { // Don't show main loading if just saving
      bodyContent = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null) {
      // ... (error message UI - keep as is) ...
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
                  onPressed: _fetchCompanyIdAndThenFoods,
                )
            ],
          ),
        ),
      );
    } else if (_foods.isEmpty && !_isLoading) { // Show "no items" only if not loading
      // ... (no items UI - keep as is) ...
      bodyContent = Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.fastfood_outlined, size: 60, color: theme.colorScheme.secondary),
              const SizedBox(height: 16),
              const Text(
                "You haven't added any food items to your menu yet.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                "Tap the '+' button to add your first item!",
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    } else {
      // ... (ListView.builder UI - keep as is, ensure PopupMenuButton calls _navigateToEditFood and _deleteFood) ...
      bodyContent = ListView.builder(
        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 80.0),
        itemCount: _foods.length,
        itemBuilder: (context, index) {
          final food = _foods[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
            elevation: 2,
            child: ListTile(
              leading: food.imageUrl != null && food.imageUrl!.isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(4.0),
                child: Image.network(
                  food.imageUrl!,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.restaurant_menu, size: 30),
                ),
              )
                  : CircleAvatar(
                backgroundColor: theme.colorScheme.secondaryContainer,
                child: Icon(Icons.restaurant_menu, color: theme.colorScheme.onSecondaryContainer, size: 24),
              ),
              title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Price: TSh ${food.price.toStringAsFixed(0)}/="),
                  if (food.description != null && food.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        food.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') {
                    _navigateToEditFood(food); // Calls _showAddEditFoodDialog
                  } else if (value == 'delete') {
                    _deleteFood(food);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit')),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(leading: Icon(Icons.delete_outline, color: theme.colorScheme.error), title: Text('Delete', style: TextStyle(color: theme.colorScheme.error))),
                  ),
                ],
              ),
              isThreeLine: food.description != null && food.description!.isNotEmpty,
              onTap: () => _navigateToEditFood(food), // Calls _showAddEditFoodDialog
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Your Menu'),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCompanyIdAndThenFoods,
        child: bodyContent,
      ),
      floatingActionButton: _isLoading || (_companyId == null && _errorMessage != null && _errorMessage!.contains("No company profile found"))
          ? null
          : FloatingActionButton.extended(
        onPressed: _companyId != null ? () => _showAddEditFoodDialog() : null, // Updated to call the dialog
        label: const Text('Add Food'),
        icon: const Icon(Icons.add),
        backgroundColor: _companyId != null ? theme.colorScheme.primary : Colors.grey,
      ),
    );
  }
}

