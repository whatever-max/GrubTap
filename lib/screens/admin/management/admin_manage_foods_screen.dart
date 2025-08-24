// lib/screens/admin/management/admin_manage_foods_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:grubtap/models/food_item_model.dart';
import 'package:grubtap/models/company_model.dart';
import 'package:grubtap/services/session_service.dart';
import 'package:grubtap/utils/string_extensions.dart';
import 'package:flutter/foundation.dart'; // for describeEnum
// import 'package:intl/intl.dart'; // Not directly used in this version
import 'package:collection/collection.dart';

class AdminManageFoodsScreen extends StatefulWidget {
  static const String routeName = '/admin-manage-foods';
  const AdminManageFoodsScreen({super.key});

  @override
  State<AdminManageFoodsScreen> createState() => _AdminManageFoodsScreenState();
}

class _AdminManageFoodsScreenState extends State<AdminManageFoodsScreen> {
  final supabase = Supabase.instance.client;
  List<FoodItemModel> _foods = [];
  List<CompanyModel> _availableCompanies = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _searchTerm;
  CompanyModel? _selectedCompanyFilter;

  final _currentUserEmail = SessionService.getCurrentUser()?.email;
  // Use ID for super admin check for robustness
  bool get _isSuperAdmin => SessionService.getCurrentUser()?.id == 'ddbf93e1-f6bd-4295-a3a6-6348fe6fdf96';


  bool _canViewAllFoods = false;
  bool _canEditAllFoods = false;
  bool _canDeleteAllFoods = false;
  bool _canAddFoodsToAnyCompany = false;

  final _foodFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _categoryController = TextEditingController();
  final _tagsController = TextEditingController();
  CompanyModel? _selectedCompanyForForm;
  FoodItemAvailability _selectedAvailability = FoodItemAvailability.available;
  final _stockCountController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    _categoryController.dispose();
    _tagsController.dispose();
    _stockCountController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });
    await _fetchAdminFoodPermissions();
    // Fetch companies regardless of food view permission, as they are needed for the "Add Food" dialog if user can add.
    await _fetchAvailableCompaniesForDropdown();
    if (_isSuperAdmin || _canViewAllFoods) {
      await _fetchFoods(searchTerm: _searchTerm, companyFilterId: _selectedCompanyFilter?.id);
    } else {
      _foods = []; // Clear foods if no permission
      _errorMessage = "You do not have permission to view food items.";
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchAdminFoodPermissions() async {
    if (_isSuperAdmin) {
      _canViewAllFoods = true; _canEditAllFoods = true; _canDeleteAllFoods = true; _canAddFoodsToAnyCompany = true;
      return;
    }
    final currentUserId = SessionService.getCurrentUser()?.id;
    if (currentUserId == null) {
      _canViewAllFoods = false; _canEditAllFoods = false; _canDeleteAllFoods = false; _canAddFoodsToAnyCompany = false;
      return;
    }
    try {
      final response = await supabase.from('admin_permissions')
          .select('can_view, can_edit, can_delete, can_invite') // can_invite for adding
          .eq('admin_user_id', currentUserId)
          .eq('permission_type', 'MANAGE_FOODS_ALL').maybeSingle();
      if (mounted) {
        if (response != null) {
          _canViewAllFoods = response['can_view'] ?? false;
          _canEditAllFoods = response['can_edit'] ?? false;
          _canDeleteAllFoods = response['can_delete'] ?? false;
          _canAddFoodsToAnyCompany = response['can_invite'] ?? false; // Using 'can_invite' for "add new"
        } else {
          _canViewAllFoods = false; _canEditAllFoods = false; _canDeleteAllFoods = false; _canAddFoodsToAnyCompany = false;
        }
      }
    } catch (e) {
      debugPrint("[ManageFoodsScreen] Error fetching permissions: $e");
      if (mounted) {
        _errorMessage = "Error loading your food management permissions.";
        _canViewAllFoods = false; _canEditAllFoods = false; _canDeleteAllFoods = false; _canAddFoodsToAnyCompany = false;
      }
    }
  }

  Future<void> _fetchAvailableCompaniesForDropdown() async {
    try {
      final response = await supabase.from('companies').select('id, name').order('name', ascending: true);
      if (!mounted) return;
      _availableCompanies = response.map((data) => CompanyModel.fromMap(data)).toList();
    } catch (e) {
      debugPrint("[ManageFoodsScreen] Error fetching companies for dropdown: $e");
      if(mounted) _errorMessage = (_errorMessage ?? "") + "\nCould not load companies list.";
      _availableCompanies = [];
    }
  }

  Future<void> _fetchFoods({String? searchTerm, String? companyFilterId}) async {
    // Permission to view is already checked in _loadInitialData
    try {
      var queryBuilder = supabase
          .from('foods') // <<< CORRECTED: 'foods' instead of 'food_items'
          .select('*, companies (name)'); // Fetches company name via foreign key

      if (companyFilterId != null && companyFilterId.isNotEmpty) {
        queryBuilder = queryBuilder.eq('company_id', companyFilterId);
      }
      if (searchTerm != null && searchTerm.isNotEmpty) {
        final st = '%${searchTerm.trim()}%';
        // Ensure 'companies.name' is correctly referenced for joined table search
        queryBuilder = queryBuilder.or('name.ilike.$st,description.ilike.$st,category.ilike.$st,companies.name.ilike.$st');
      }

      final orderedQueryBuilder = queryBuilder.order('name', ascending: true);
      final response = await orderedQueryBuilder;

      if (!mounted) return;
      _foods = response.map((data) => FoodItemModel.fromMap(data)).toList();

      if (_foods.isEmpty && (searchTerm?.isNotEmpty == true || companyFilterId?.isNotEmpty == true)) {
        if(mounted) setState(() => _errorMessage = 'No food items match your criteria.');
      } else if (mounted) {
        setState(() => _errorMessage = null);
      }
    } catch (e) {
      if (mounted) {
        debugPrint("[ManageFoodsScreen] Error fetching food items: $e");
        setState(() {
          _errorMessage = "Error fetching food items: ${e.toString()}";
          _foods = [];
        });
      }
    }
  }

  void _clearFoodFormControllers() {
    _nameController.clear();
    _descriptionController.clear();
    _priceController.clear();
    _imageUrlController.clear();
    _categoryController.clear();
    _tagsController.clear();
    _stockCountController.clear();
    _selectedCompanyForForm = null;
    _selectedAvailability = FoodItemAvailability.available;
  }

  Future<void> _showAddEditFoodDialog({FoodItemModel? foodToEdit}) async {
    final bool isEditMode = foodToEdit != null;
    final bool canPerformAction = isEditMode
        ? (_isSuperAdmin || _canEditAllFoods)
        : (_isSuperAdmin || _canAddFoodsToAnyCompany);

    if (!canPerformAction) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('You do not have permission to ${isEditMode ? "edit" : "add"} food items.')));
      return;
    }

    _clearFoodFormControllers();

    if (isEditMode && foodToEdit != null) {
      _nameController.text = foodToEdit.name;
      _descriptionController.text = foodToEdit.description ?? '';
      _priceController.text = foodToEdit.price.toString();
      _imageUrlController.text = foodToEdit.imageUrl ?? '';
      _categoryController.text = foodToEdit.category ?? '';
      _tagsController.text = foodToEdit.tags?.join(', ') ?? '';
      _selectedAvailability = foodToEdit.availability;
      _stockCountController.text = foodToEdit.stockCount?.toString() ?? '';
      _selectedCompanyForForm = _availableCompanies.firstWhereOrNull((c) => c.id == foodToEdit.companyId);
    } else {
      _selectedCompanyForForm = _selectedCompanyFilter ?? (_availableCompanies.isNotEmpty ? _availableCompanies.first : null);
    }

    final bool? success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isDialogSaving = false;
        // Use local state for dialog-specific dropdowns to avoid conflicts with main screen state
        CompanyModel? dialogSelectedCompany = _selectedCompanyForForm;
        FoodItemAvailability dialogSelectedAvailability = _selectedAvailability;

        return StatefulBuilder(builder: (stfContext, stfSetStateDialog) {
          return AlertDialog(
            title: Text(isEditMode ? 'Edit Food Item' : 'Add New Food Item'),
            content: SingleChildScrollView(
              child: Form(
                key: _foodFormKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (_availableCompanies.isNotEmpty)
                    DropdownButtonFormField<CompanyModel>(
                      value: dialogSelectedCompany,
                      items: _availableCompanies.map((CompanyModel company) =>
                          DropdownMenuItem<CompanyModel>(value: company, child: Text(company.name))).toList(),
                      onChanged: isDialogSaving ? null : (CompanyModel? newValue) {
                        stfSetStateDialog(() => dialogSelectedCompany = newValue);
                      },
                      decoration: const InputDecoration(labelText: 'Company*'),
                      validator: (val) => val == null ? 'Please select a company.' : null,
                      disabledHint: dialogSelectedCompany != null ? Text(dialogSelectedCompany!.name) : null,
                      isExpanded: true,
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text('No companies available. Please add a company first.', style: TextStyle(color: Colors.red)),
                    ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Food Name*'), validator: (val) => (val?.trim().isEmpty ?? true) ? 'Name is required.' : null, enabled: !isDialogSaving),
                  const SizedBox(height: 12),
                  TextFormField(controller: _priceController, decoration: const InputDecoration(labelText: 'Price*', prefixText: '\$ '), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (val) { if (val?.trim().isEmpty ?? true) return 'Price is required.'; if (double.tryParse(val!.trim()) == null || double.parse(val.trim()) < 0) return 'Invalid price.'; return null;}, enabled: !isDialogSaving),
                  const SizedBox(height: 12),
                  TextFormField(controller: _descriptionController, decoration: const InputDecoration(labelText: 'Description (Optional)'), maxLines: 2, enabled: !isDialogSaving),
                  const SizedBox(height: 12),
                  TextFormField(controller: _categoryController, decoration: const InputDecoration(labelText: 'Category (e.g., Appetizer)'), enabled: !isDialogSaving),
                  const SizedBox(height: 12),
                  TextFormField(controller: _imageUrlController, decoration: const InputDecoration(labelText: 'Image URL (Optional)'), keyboardType: TextInputType.url, enabled: !isDialogSaving),
                  const SizedBox(height: 12),
                  TextFormField(controller: _tagsController, decoration: const InputDecoration(labelText: 'Tags (comma-separated)'), enabled: !isDialogSaving),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<FoodItemAvailability>(
                    value: dialogSelectedAvailability,
                    items: FoodItemAvailability.values.map((FoodItemAvailability av) =>
                        DropdownMenuItem<FoodItemAvailability>(value: av, child: Text(describeEnum(av).capitalizeFirst()))).toList(),
                    onChanged: isDialogSaving ? null : (FoodItemAvailability? newVal) {
                      if (newVal != null) stfSetStateDialog(() => dialogSelectedAvailability = newVal);
                    },
                    decoration: const InputDecoration(labelText: 'Availability*'),
                    isExpanded: true,
                  ),
                  if (dialogSelectedAvailability == FoodItemAvailability.limited) ...[
                    const SizedBox(height: 12),
                    TextFormField(controller: _stockCountController, decoration: const InputDecoration(labelText: 'Stock Count*'), keyboardType: TextInputType.number, validator: (val) { if (val?.trim().isEmpty ?? true || int.tryParse(val!.trim()) == null || int.parse(val.trim()) < 0) return 'Valid stock count required.'; return null;}, enabled: !isDialogSaving),
                  ],
                ]),
              ),
            ),
            actions: [
              TextButton(onPressed: isDialogSaving ? null : () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isDialogSaving || (_availableCompanies.isEmpty && dialogSelectedCompany == null)
                    ? null
                    : () async {
                  if (_foodFormKey.currentState!.validate()) {
                    if (dialogSelectedCompany == null) { // Check dialog's selected company
                      ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Please select a company.'), backgroundColor: Colors.red));
                      return;
                    }
                    stfSetStateDialog(() => isDialogSaving = true);
                    final currentAdminUserId = SessionService.getCurrentUser()?.id;
                    if (currentAdminUserId == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Error: User session not found.'), backgroundColor: Colors.red));
                      stfSetStateDialog(() => isDialogSaving = false);
                      return;
                    }

                    List<String>? tagsList = _tagsController.text.trim().isNotEmpty
                        ? _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
                        : null;

                    try {
                      if (isEditMode) {
                        final updatedFood = FoodItemModel(
                          id: foodToEdit!.id,
                          companyId: dialogSelectedCompany!.id, // Use dialog's company
                          name: _nameController.text.trim(),
                          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                          price: double.parse(_priceController.text.trim()),
                          imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
                          category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
                          tags: tagsList,
                          availability: dialogSelectedAvailability, // Use dialog's availability
                          stockCount: dialogSelectedAvailability == FoodItemAvailability.limited
                              ? (int.tryParse(_stockCountController.text.trim()) ?? 0)
                              : null,
                          createdAt: foodToEdit.createdAt,
                          updatedAt: DateTime.now(),
                          createdByUserId: foodToEdit.createdByUserId,
                        );
                        await supabase.from('foods').update(updatedFood.toMapForUpdate()).eq('id', foodToEdit.id); // <<< CORRECTED
                      } else {
                        final newFood = FoodItemModel(
                          id: '', // Will be generated by DB or leave empty for Supabase to handle if auto-gen PK
                          companyId: dialogSelectedCompany!.id, // Use dialog's company
                          name: _nameController.text.trim(),
                          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                          price: double.parse(_priceController.text.trim()),
                          imageUrl: _imageUrlController.text.trim().isEmpty ? null : _imageUrlController.text.trim(),
                          category: _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
                          tags: tagsList,
                          availability: dialogSelectedAvailability, // Use dialog's availability
                          stockCount: dialogSelectedAvailability == FoodItemAvailability.limited
                              ? (int.tryParse(_stockCountController.text.trim()) ?? 0)
                              : null,
                          createdAt: DateTime.now(),
                          updatedAt: DateTime.now(),
                          createdByUserId: currentAdminUserId,
                        );
                        await supabase.from('foods').insert(newFood.toMapForInsert(currentAdminUserId)); // <<< CORRECTED
                      }
                      if (mounted) Navigator.of(dialogContext).pop(true);
                    } catch (e) {
                      debugPrint("[FoodDialog] Error saving food: $e");
                      if (mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Save failed: ${e.toString()}'), backgroundColor: Theme.of(dialogContext).colorScheme.error));
                    } finally {
                      if (mounted) stfSetStateDialog(() => isDialogSaving = false);
                    }
                  }
                },
                child: isDialogSaving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Save'),
              )
            ],
          );
        });
      },
    );
    if (success == true) {
      // Refresh the main list
      _fetchFoods(searchTerm: _searchTerm, companyFilterId: _selectedCompanyFilter?.id);
    }
  }

  Future<void> _deleteFoodItem(FoodItemModel foodToDelete) async {
    final bool canPerform = _isSuperAdmin || _canDeleteAllFoods;
    if (!canPerform) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You do not have permission to delete food items.')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete food item "${foodToDelete.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              child: const Text('DELETE')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await supabase
            .from('foods') // <<< CORRECTED
            .delete()
            .eq('id', foodToDelete.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Food item "${foodToDelete.name}" deleted.'), backgroundColor: Colors.green));
          _fetchFoods(searchTerm: _searchTerm, companyFilterId: _selectedCompanyFilter?.id); // Refresh list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Delete Error: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isSuperAdmin && !_canViewAllFoods && !_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Food Items')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_errorMessage ?? 'Access Denied: You do not have permission to view food items.',
                style: TextStyle(color: theme.colorScheme.error, fontSize: 16), textAlign: TextAlign.center),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Food Items'),
        actions: [
          if (_isSuperAdmin || _canAddFoodsToAnyCompany)
            IconButton(
                icon: const Icon(Icons.add_shopping_cart_outlined),
                tooltip: 'Add New Food Item',
                onPressed: _isLoading ? null : () => _showAddEditFoodDialog()),
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Food Items',
              onPressed: _isLoading ? null : () => _loadInitialData()),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    onChanged: (value) {
                      if (mounted) {
                        setState(() => _searchTerm = value);
                        Future.delayed(const Duration(milliseconds: 400), () {
                          if (mounted && _searchTerm == value) {
                            _fetchFoods(searchTerm: value, companyFilterId: _selectedCompanyFilter?.id);
                          }
                        });
                      }
                    },
                    decoration: InputDecoration(
                        hintText: 'Search name, category, company...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<CompanyModel?>(
                    value: _selectedCompanyFilter,
                    hint: const Text('All Companies'),
                    isExpanded: true,
                    decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                        contentPadding: const EdgeInsets.symmetric(vertical:0, horizontal: 16),
                        filled: true
                    ),
                    items: [
                      const DropdownMenuItem<CompanyModel?>(value: null, child: Text("All Companies")),
                      ..._availableCompanies
                          .map((CompanyModel c) => DropdownMenuItem<CompanyModel?>(value: c, child: Text(c.name, overflow: TextOverflow.ellipsis)))
                    ],
                    onChanged: (CompanyModel? newVal) {
                      setState(() {
                        _selectedCompanyFilter = newVal;
                        _fetchFoods(searchTerm: _searchTerm, companyFilterId: _selectedCompanyFilter?.id);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null && _foods.isEmpty
                ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error, fontSize: 16), textAlign: TextAlign.center),
                )
            )
                : _foods.isEmpty
                ? Center(
                child: Text(_searchTerm?.isNotEmpty == true || _selectedCompanyFilter != null
                    ? 'No food items match your search criteria.'
                    : 'No food items found. Add some!'))
                : ListView.separated(
              itemCount: _foods.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final food = _foods[index];
                final bool canEditThis = _isSuperAdmin || _canEditAllFoods;
                final bool canDeleteThis = _isSuperAdmin || _canDeleteAllFoods;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                    backgroundImage: food.imageUrl?.isNotEmpty == true && Uri.tryParse(food.imageUrl!)?.isAbsolute == true
                        ? NetworkImage(food.imageUrl!)
                        : null,
                    child: (food.imageUrl?.isEmpty ?? true || Uri.tryParse(food.imageUrl!)?.isAbsolute == false) && food.name.isNotEmpty
                        ? Text(food.name[0].toUpperCase())
                        : null,
                  ),
                  title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (food.companyName != null)
                        Text("From: ${food.companyName!}", style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                      Text("\$${food.price.toStringAsFixed(2)}", style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600)),
                      if (food.category?.isNotEmpty == true) Text("Category: ${food.category}", style: theme.textTheme.bodySmall),
                      Text("Status: ${describeEnum(food.availability).capitalizeFirst()}", style: theme.textTheme.bodySmall),
                      if (food.tags?.isNotEmpty == true)
                        Wrap(
                            spacing: 4,
                            runSpacing: 0,
                            children: food.tags!
                                .map((tag) => Chip(
                                label: Text(tag),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                labelStyle: const TextStyle(fontSize: 10)))
                                .toList()),
                    ],
                  ),
                  trailing: (canEditThis || canDeleteThis)
                      ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (val) {
                      if (val == 'edit') _showAddEditFoodDialog(foodToEdit: food);
                      if (val == 'delete') _deleteFoodItem(food);
                    },
                    itemBuilder: (_) => <PopupMenuEntry<String>>[
                      if (canEditThis)
                        const PopupMenuItem<String>(
                            value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
                      if (canDeleteThis)
                        PopupMenuItem<String>(
                            value: 'delete',
                            child: ListTile(
                                leading: Icon(Icons.delete_outline, color: theme.colorScheme.error),
                                title: Text('Delete', style: TextStyle(color: theme.colorScheme.error)))),
                    ],
                  )
                      : null,
                  onTap: canEditThis ? () => _showAddEditFoodDialog(foodToEdit: food) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

