// lib/screens/company/company_menu_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/food_model.dart';
import '../../models/company_model.dart';
import '../../widgets/app_background.dart';
// !!! IMPORT Your OrderNowScreen !!!
import '../order/order_now_screen.dart'; // Make sure this path is correct

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
  CompanyModel? _companyDetails;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchCompanyDetailsAndMenu();
  }

  Future<void> _fetchCompanyDetailsAndMenu() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch company details
      final companyResponse = await supabase
          .from('companies')
          .select()
          .eq('id', widget.companyId)
          .maybeSingle();

      // Fetch menu items for the company
      // Ensure your 'foods' table has a 'company_id' column that references 'companies.id'
      // And that FoodModel.fromMap can handle the 'companies(*)' join if you need company details PER food item.
      // For this screen, we primarily need food details. The company details are fetched once.
      final menuResponse = await supabase
          .from('foods')
          .select('*, companies(id, name, logo_url)') // Join with companies table
          .eq('company_id', widget.companyId)
          .order('name', ascending: true);

      if (!mounted) return;

      setState(() {
        if (companyResponse != null) {
          _companyDetails = CompanyModel.fromMap(companyResponse as Map<String, dynamic>);
        } else {
          // Fallback if company details couldn't be fetched but we have the name
          debugPrint("Could not fetch full company details for ID: ${widget.companyId}. Using provided name.");
        }

        _menuItems = (menuResponse as List<dynamic>)
            .map((itemData) => FoodModel.fromMap(itemData as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } on PostgrestException catch (e) {
      if (mounted) {
        debugPrint('Supabase error fetching company menu: ${e.message}');
        setState(() {
          _errorMessage = "Failed to load menu: ${e.message}";
          _isLoading = false;
        });
      }
    } catch (e, stacktrace) {
      if (mounted) {
        debugPrint('Unexpected error fetching company menu: $e\n$stacktrace');
        setState(() {
          _errorMessage = "An unexpected error occurred: $e";
          _isLoading = false;
        });
      }
    }
  }

  // THIS IS THE CORRECTED NAVIGATION METHOD
  void _navigateToOrderScreenWithItem(FoodModel food) {
    // Before navigating, ensure the 'food.company' is potentially set if OrderNowScreen
    // or its subsequent screens might need it directly from the FoodModel.
    // Your FoodModel.fromMap should ideally handle parsing the nested 'companies' data
    // from the Supabase query into food.company.
    // If food.company is null here, but you have _companyDetails, you could assign it:
    // FoodModel foodWithCompany = food.copyWith(company: _companyDetails);
    // Then pass foodWithCompany to OrderNowScreen.
    // For simplicity now, we assume FoodModel.fromMap handles the company relation.

    Navigator.push(
      context,
      MaterialPageRoute(
        // The key fix: Correctly instantiating *your* OrderNowScreen
        // and passing the 'initialFoodItem' parameter.
        builder: (context) => OrderNowScreen(initialFoodItem: food),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            _companyDetails?.name ?? widget.companyName, // Use fetched name or fallback
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
          backgroundColor: Colors.transparent, // Theme dependent
          elevation: 0,
          iconTheme: IconThemeData(color: theme.colorScheme.onPrimaryContainer),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _fetchCompanyDetailsAndMenu,
              tooltip: "Refresh Menu",
            )
          ],
        ),
        body: _buildBody(theme),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error, fontSize: 16)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                onPressed: _fetchCompanyDetailsAndMenu,
                style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.errorContainer,
                    foregroundColor: theme.colorScheme.onErrorContainer),
              ),
            ],
          ),
        ),
      );
    }

    if (_menuItems.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.no_food_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                "No menu items available for ${_companyDetails?.name ?? widget.companyName} at the moment.",
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchCompanyDetailsAndMenu,
      child: ListView.separated(
        padding: const EdgeInsets.all(16.0),
        itemCount: _menuItems.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final food = _menuItems[index];

          return Card(
            elevation: 2,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: InkWell(
              // This correctly calls the method that correctly instantiates OrderNowScreen
              onTap: () => _navigateToOrderScreenWithItem(food),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: (food.imageUrl != null &&
                            food.imageUrl!.isNotEmpty &&
                            Uri.tryParse(food.imageUrl!)?.hasAbsolutePath == true)
                            ? Image.network(
                          food.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator.adaptive(
                                value: loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                    : null,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                            child: Icon(Icons.fastfood_outlined, size: 30, color: theme.colorScheme.onSecondaryContainer),
                          ),
                        )
                            : Container(
                          color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                          child: Icon(Icons.fastfood_outlined, size: 30, color: theme.colorScheme.onSecondaryContainer),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            food.name,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (food.description != null && food.description!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                food.description!,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            "\$${food.price.toStringAsFixed(2)}",
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.add_shopping_cart_outlined, size: 22, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
