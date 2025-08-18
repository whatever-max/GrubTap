// lib/screens/order/order_now_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/company_model.dart';
import '../../models/food_model.dart';
import '../../widgets/app_background.dart';
import '../company/company_menu_screen.dart';
import '../food/food_details_screen.dart'; // <<< ENSURE THIS IMPORT IS CORRECT AND FILE EXISTS

class OrderNowScreen extends StatefulWidget {
  final FoodModel? initialFoodItem;

  const OrderNowScreen({
    super.key,
    this.initialFoodItem,
  });

  @override
  State<OrderNowScreen> createState() => _OrderNowScreenState();
}

class _OrderNowScreenState extends State<OrderNowScreen> {
  final supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  final List<FoodModel> _currentOrderItems = [];

  List<dynamic> _searchResults = [];
  List<CompanyModel> _initialCompanies = [];
  List<FoodModel> _initialFoods = [];

  bool _isLoadingInitial = true;
  bool _isSearching = false;
  bool _searchFieldHasText = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    if (widget.initialFoodItem != null) {
      _addItemToCurrentOrder(widget.initialFoodItem!, showSnackbar: false);
    }

    _fetchInitialSuggestions();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _addItemToCurrentOrder(FoodModel food, {bool showSnackbar = false}) {
    if (!mounted) return;
    final isAlreadyAdded = _currentOrderItems.any((item) => item.id == food.id);

    if (!isAlreadyAdded) {
      setState(() {
        _currentOrderItems.add(food);
      });
      if (showSnackbar) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${food.name} added to your order.'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else if (showSnackbar) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${food.name} is already in your order. You can adjust quantity in cart.'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _removeItemFromCurrentOrder(int index, {bool showUndo = false}) {
    if (!mounted) return;
    if (index >= 0 && index < _currentOrderItems.length) {
      final FoodModel removedItem = _currentOrderItems[index];
      setState(() {
        _currentOrderItems.removeAt(index);
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${removedItem.name} removed from your order.'),
          duration: showUndo ? const Duration(seconds: 4) : const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: showUndo ? SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              if (mounted) {
                setState(() {
                  _currentOrderItems.insert(index, removedItem);
                });
              }
            },
          ) : null,
        ),
      );
    }
  }

  Future<void> _fetchInitialSuggestions({bool isRetry = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingInitial = true;
      if (isRetry) _errorMessage = null;
    });

    try {
      final companiesDataFuture = supabase
          .from('companies')
          .select('id, name, description, logo_url')
          .order('name', ascending: true)
          .limit(5);

      final foodsDataFuture = supabase
          .from('foods')
          .select('*, companies(id, name, logo_url)')
          .order('created_at', ascending: false)
          .limit(5);

      final results = await Future.wait([companiesDataFuture, foodsDataFuture]);

      final List<Map<String, dynamic>> companiesData =
      List<Map<String, dynamic>>.from(results[0] as List<dynamic>);
      final List<Map<String, dynamic>> foodsData =
      List<Map<String, dynamic>>.from(results[1] as List<dynamic>);

      if (mounted) {
        setState(() {
          _initialCompanies = companiesData
              .map((data) => CompanyModel.fromMap(data))
              .toList();
          _initialFoods =
              foodsData.map((data) => FoodModel.fromMap(data)).toList();
          _isLoadingInitial = false;
        });
      }
    } on PostgrestException catch (e) {
      debugPrint(
          'Supabase error fetching initial suggestions (OrderNowScreen): ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load suggestions: ${e.message}';
          _isLoadingInitial = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint(
          'Unexpected error fetching initial suggestions (OrderNowScreen): $e \n$stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred.';
          _isLoadingInitial = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    if (!mounted) return;

    final hasText = _searchController.text.trim().isNotEmpty;
    if (_searchFieldHasText != hasText) {
      setState(() {
        _searchFieldHasText = hasText;
      });
    }

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_searchController.text.trim().isNotEmpty) {
        _performSearch(_searchController.text.trim());
      } else {
        setState(() {
          _searchResults = [];
          _errorMessage = null;
          if(_isSearching) _isSearching = false;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      final companyResultsFuture = supabase
          .from('companies')
          .select('id, name, description, logo_url')
          .or('name.ilike.%$query%,description.ilike.%$query%')
          .limit(5);

      // Assuming 'company_name_cache' might be a text field in your 'foods' table
      // that stores the company name for faster text search.
      // If it's not, you might need to adjust this query or rely on joining.
      final foodResultsFuture = supabase
          .from('foods')
          .select('*, companies(id, name, logo_url)')
          .or('name.ilike.%$query%,description.ilike.%$query%,company_name.ilike.%$query%') // Using company_name from join
          .limit(10);

      final results = await Future.wait([companyResultsFuture, foodResultsFuture]);

      final List<CompanyModel> companies =
      (List<Map<String, dynamic>>.from(results[0] as List<dynamic>))
          .map((data) => CompanyModel.fromMap(data))
          .toList();
      final List<FoodModel> foods =
      (List<Map<String, dynamic>>.from(results[1] as List<dynamic>))
          .map((data) => FoodModel.fromMap(data))
          .toList();

      if (mounted) {
        setState(() {
          _searchResults = [...companies, ...foods];
          if (_searchResults.isEmpty && query.isNotEmpty) {
            _errorMessage = 'No results found for "$query".';
          }
          _isSearching = false;
        });
      }
    } on PostgrestException catch (e) {
      debugPrint('Supabase search error (OrderNowScreen): ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = 'Search failed: ${e.message}';
          _searchResults = [];
          _isSearching = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Unexpected search error (OrderNowScreen): $e \n$stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred during search.';
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
  }

  void _navigateToCompany(CompanyModel company) {
    if (company.id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Company ID is missing for ${company.name}.")),
        );
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompanyMenuScreen(
          companyId: company.id,
          companyName: company.name,
        ),
      ),
    );
  }

  void _handleFoodItemTap(FoodModel food) {
    _addItemToCurrentOrder(food, showSnackbar: true);
  }

  void _navigateToFoodDetails(FoodModel food) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailsScreen(food: food),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double totalOrderAmount = _currentOrderItems.fold(0.0, (sum, item) => sum + item.price);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(
            _currentOrderItems.isEmpty ? 'Find Food or Restaurants' : 'Your Current Order',
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: theme.colorScheme.onPrimaryContainer),
          actions: _currentOrderItems.isNotEmpty
              ? [
            IconButton(
              icon: Icon(Icons.delete_sweep_outlined, color: theme.colorScheme.error),
              tooltip: "Clear Current Order",
              onPressed: () {
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text("Clear Order"),
                        content: const Text("Are you sure you want to remove all items from your order?"),
                        actions: <Widget>[
                          TextButton(
                            child: const Text("Cancel"),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                            },
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                            child: const Text("Clear All"),
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              setState(() {
                                _currentOrderItems.clear();
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Order cleared."),
                                  duration: Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  );
                }
              },
            )
          ]
              : null,
        ),
        body: Column(
          children: [
            if (_currentOrderItems.isNotEmpty)
              _buildCurrentOrderSummary(theme, totalOrderAmount),

            Padding(
              padding: EdgeInsets.fromLTRB(16.0, _currentOrderItems.isNotEmpty ? 4.0 : 8.0, 16.0, 12.0),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                decoration: InputDecoration(
                  hintText: 'Search dishes or restaurants...',
                  hintStyle: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
                  prefixIcon: Icon(Icons.search,
                      color: theme.colorScheme.onSurfaceVariant),
                  suffixIcon: _searchFieldHasText && !_isSearching
                      ? IconButton(
                    icon: Icon(Icons.clear,
                        color: theme.colorScheme.onSurfaceVariant),
                    onPressed: _clearSearch,
                  )
                      : _isSearching
                      ? Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.0,
                            color: theme.colorScheme.primary)),
                  )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30.0),
                    borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 1.5),
                  ),
                ),
                style: TextStyle(color: theme.colorScheme.onSurface),
              ),
            ),
            if (_errorMessage != null &&
                ((_searchController.text.trim().isEmpty && !_isLoadingInitial) ||
                    (_searchController.text.trim().isNotEmpty && !_isSearching && _searchResults.isEmpty)))
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: _buildContent(theme),
            ),

            if (_currentOrderItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.payment_outlined),
                  label: Text("Checkout (\S${totalOrderAmount.toStringAsFixed(2)})"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    // TODO: Implement actual checkout logic
                    // Example: Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen(orderItems: _currentOrderItems)));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Proceeding to Checkout (Not Implemented)")),
                    );
                  },
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentOrderSummary(ThemeData theme, double totalAmount) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Order Items (${_currentOrderItems.length})",
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurfaceVariant),
              ),
              Text(
                "\$${totalAmount.toStringAsFixed(2)}",
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary),
              ),
            ],
          ),
          const Divider(height: 12, thickness: 0.5),
          SizedBox(
            height: _currentOrderItems.length > 3 ? 120 : null,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _currentOrderItems.length,
              itemBuilder: (context, index) {
                final item = _currentOrderItems[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "\$${item.price.toStringAsFixed(2)}",
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      IconButton(
                        icon: Icon(Icons.remove_circle_outline,
                            size: 20, color: theme.colorScheme.error.withOpacity(0.8)),
                        padding: const EdgeInsets.only(left: 8),
                        constraints: const BoxConstraints(),
                        tooltip: "Remove ${item.name}",
                        onPressed: () => _removeItemFromCurrentOrder(index, showUndo: true),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildContent(ThemeData theme) {
    final bool hasSearchText = _searchController.text.trim().isNotEmpty;

    if (hasSearchText) {
      if (_isSearching) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_errorMessage != null && _searchResults.isEmpty) {
        return _buildErrorState(theme, _errorMessage!, () => _performSearch(_searchController.text.trim()));
      }
      if (_searchResults.isEmpty) {
        final message = _errorMessage ?? 'No results found for "${_searchController.text.trim()}".\nTry a different search!';
        return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ));
      }
      return _buildSearchResultsList(theme);
    } else {
      if (_isLoadingInitial) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_errorMessage != null && _initialCompanies.isEmpty && _initialFoods.isEmpty) {
        return _buildErrorState(theme, _errorMessage!, () => _fetchInitialSuggestions(isRetry: true));
      }
      if (_initialCompanies.isEmpty && _initialFoods.isEmpty && _currentOrderItems.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Start by searching for your favorite food or restaurant above!',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        );
      }
      return _buildInitialSuggestionsList(theme);
    }
  }

  Widget _buildErrorState(ThemeData theme, String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: theme.textTheme.titleMedium
                  ?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.errorContainer,
                foregroundColor: theme.colorScheme.onErrorContainer,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
              onPressed: onRetry,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInitialSuggestionsList(ThemeData theme) {
    List<Widget> suggestionWidgets = [];

    if (_initialCompanies.isNotEmpty) {
      suggestionWidgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 10.0),
          child: Text("Popular Restaurants",
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onBackground.withOpacity(0.9))),
        ),
      );
      suggestionWidgets.addAll(_initialCompanies
          .map((company) => _buildCompanyTile(company, theme, isSuggestion: true))
          .toList());
    }

    if (_initialFoods.isNotEmpty) {
      suggestionWidgets.add(
        Padding(
          padding: EdgeInsets.fromLTRB(16.0,
              _initialCompanies.isNotEmpty ? 20.0 : 8.0, 16.0, 10.0),
          child: Text("Popular Dishes",
              style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onBackground.withOpacity(0.9))),
        ),
      );
      suggestionWidgets.addAll(_initialFoods
          .map((food) => _buildFoodTile(food, theme, isSuggestion: true))
          .toList());
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: suggestionWidgets,
    );
  }

  Widget _buildSearchResultsList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        if (item is CompanyModel) {
          return _buildCompanyTile(item, theme);
        } else if (item is FoodModel) {
          return _buildFoodTile(item, theme);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCompanyTile(CompanyModel company, ThemeData theme, {bool isSuggestion = false}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 12.0),
      elevation: isSuggestion ? 1.5 : 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: theme.colorScheme.surface.withOpacity(isSuggestion ? 0.9 : 1.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        leading: (company.logoUrl != null &&
            company.logoUrl!.isNotEmpty &&
            Uri.tryParse(company.logoUrl!)?.hasAbsolutePath == true)
            ? CircleAvatar(
          radius: 26,
          backgroundImage: NetworkImage(company.logoUrl!),
          onBackgroundImageError: (_, __) {},
          backgroundColor: theme.colorScheme.secondaryContainer,
        )
            : CircleAvatar(
          radius: 26,
          backgroundColor: theme.colorScheme.secondaryContainer,
          child: Icon(Icons.business,
              color: theme.colorScheme.onSecondaryContainer, size: 26),
        ),
        title: Text(
          company.name,
          style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface),
        ),
        subtitle: company.description != null && company.description!.isNotEmpty
            ? Text(
          company.description!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        )
            : null,
        trailing: Icon(Icons.chevron_right,
            color: theme.colorScheme.outline.withOpacity(0.7)),
        onTap: () => _navigateToCompany(company),
      ),
    );
  }

  Widget _buildFoodTile(FoodModel food, ThemeData theme, {bool isSuggestion = false}) {
    // Corrected line: Using food.company?.name and falling back to 'Unknown Restaurant'
    final String companyName = food.company?.name ?? 'Unknown Restaurant';
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 12.0),
      elevation: isSuggestion ? 1.5 : 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: theme.colorScheme.surface.withOpacity(isSuggestion ? 0.9 : 1.0),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        leading: (food.imageUrl != null &&
            food.imageUrl!.isNotEmpty &&
            Uri.tryParse(food.imageUrl!)?.hasAbsolutePath == true)
            ? SizedBox(
          width: 55,
          height: 55,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              food.imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.fastfood_outlined,
                      color: theme.colorScheme.onSecondaryContainer.withOpacity(0.7),
                      size: 30)),
            ),
          ),
        )
            : Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.fastfood_outlined,
              color: theme.colorScheme.onSecondaryContainer.withOpacity(0.7), size: 30),
        ),
        title: Text(
          food.name,
          style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface),
        ),
        subtitle: Text(
          "from $companyName\n\$${food.price.toStringAsFixed(2)}",
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        trailing: Icon(Icons.add_shopping_cart_outlined,
            color: theme.colorScheme.primary.withOpacity(0.8)),
        onTap: () => _handleFoodItemTap(food),
      ),
    );
  }
}
