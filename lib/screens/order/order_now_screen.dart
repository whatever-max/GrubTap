// lib/screens/order/order_now_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/company_model.dart';
import '../../models/food_model.dart'; // FoodModel should now have .company and .companyName
import '../../widgets/app_background.dart'; // Assuming you have this
import '../company/company_menu_screen.dart'; // To navigate to a company's menu
// If you have a screen to show food details or add to cart, import it here
// import '../food/food_details_screen.dart';

class OrderNowScreen extends StatefulWidget {
  const OrderNowScreen({super.key});

  @override
  State<OrderNowScreen> createState() => _OrderNowScreenState();
}

class _OrderNowScreenState extends State<OrderNowScreen> {
  final supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<dynamic> _searchResults = []; // Can hold CompanyModel or FoodModel
  List<CompanyModel> _initialCompanies = [];
  List<FoodModel> _initialFoods = [];

  bool _isSearching = false; // True when actively performing a debounced search
  bool _isLoadingInitial = true; // True when fetching initial suggestions
  bool _isPerformingSearch = false; // True when the search text is not empty
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchInitialSuggestions();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitialSuggestions() async {
    if (!mounted) return;
    setState(() {
      _isLoadingInitial = true;
      _errorMessage = null;
    });

    try {
      final companiesData = await supabase
          .from('companies')
          .select<List<Map<String, dynamic>>>()
          .order('name', ascending: true)
          .limit(5); // Suggest a few companies

      final foodsData = await supabase
          .from('foods')
          .select<List<Map<String, dynamic>>>('*, companies(id, name, logo_url)') // Join to get company info
          .order('created_at', ascending: false) // Show newest popular items
          .limit(5); // Suggest a few food items

      if (mounted) {
        setState(() {
          _initialCompanies = companiesData.map((data) => CompanyModel.fromMap(data)).toList();
          _initialFoods = foodsData.map((data) => FoodModel.fromMap(data)).toList();
          _isLoadingInitial = false;
        });
      }
    } on PostgrestException catch (e) {
      debugPrint('Supabase error fetching initial suggestions (OrderNowScreen): ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load suggestions.';
          _isLoadingInitial = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Unexpected error fetching initial suggestions (OrderNowScreen): $e \n$stackTrace');
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

    setState(() {
      _isPerformingSearch = _searchController.text.isNotEmpty;
    });

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      } else {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false; // No longer actively searching
          });
        }
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isSearching = true; // Indicate that a search is in progress
      _errorMessage = null;
    });

    try {
      // Search for companies
      final companyResultsFuture = supabase
          .from('companies')
          .select<List<Map<String, dynamic>>>()
          .or('name.ilike.%$query%,description.ilike.%$query%') // Search in name and description
          .limit(5);

      // Search for foods, including their company's name
      final foodResultsFuture = supabase
          .from('foods')
          .select<List<Map<String, dynamic>>>('*, companies(id, name, logo_url)')
          .or('name.ilike.%$query%,description.ilike.%$query%,companies.name.ilike.%$query%')
          .limit(10);

      final results = await Future.wait([companyResultsFuture, foodResultsFuture]);

      final List<CompanyModel> companies = (results[0]).map((data) => CompanyModel.fromMap(data)).toList();
      final List<FoodModel> foods = (results[1]).map((data) => FoodModel.fromMap(data)).toList();

      if (mounted) {
        setState(() {
          _searchResults = [...companies, ...foods]; // Combine results
          _isSearching = false;
        });
      }
    } on PostgrestException catch (e) {
      debugPrint('Supabase search error (OrderNowScreen): ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = 'Search failed. Please try again.';
          _isSearching = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Unexpected search error (OrderNowScreen): $e \n$stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred during search.';
          _isSearching = false;
        });
      }
    }
  }

  void _navigateToCompany(CompanyModel company) {
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

  void _navigateToFoodItem(FoodModel food) {
    // Navigate to a FoodDetailsScreen or add directly to an order concept
    // This assumes food.company is populated by the Supabase query & FoodModel.fromMap
    if (food.company != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tapped on ${food.name} from ${food.company!.name}')),
      );
      // Example navigation (if you have a FoodDetailsScreen):
      // Navigator.push(context, MaterialPageRoute(builder: (_) => FoodDetailsScreen(food: food, company: food.company!)));
    } else {
      // Fallback if company details are missing for some reason
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tapped on ${food.name}. Company details missing.')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return AppBackground( // Assuming AppBackground provides a themed background
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Find Food or Restaurants'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search for dishes or restaurants...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor.withAlpha(150), // Slightly transparent fill
                  suffixIcon: _isPerformingSearch
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      // _searchResults will clear via _onSearchChanged
                    },
                  )
                      : null,
                ),
              ),
            ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
              ),
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    // If actively typing and searching
    if (_isPerformingSearch) {
      if (_isSearching) { // While the debounced search is running
        return const Center(child: CircularProgressIndicator());
      }
      if (_searchResults.isEmpty && !_isSearching) {
        return const Center(child: Text('No results found. Try a different search!'));
      }
      return _buildSearchResultsList();
    }

    // Initial state or when search bar is empty
    if (_isLoadingInitial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_initialCompanies.isEmpty && _initialFoods.isEmpty && _errorMessage == null) {
      return const Center(child: Text('Start by searching for your favorite food or restaurant.'));
    }
    return _buildInitialSuggestionsList();
  }

  Widget _buildInitialSuggestionsList() {
    if (_initialCompanies.isEmpty && _initialFoods.isEmpty) {
      return const Center(child: Text("No initial suggestions available. Try searching!"));
    }

    List<Widget> suggestionWidgets = [];

    if (_initialCompanies.isNotEmpty) {
      suggestionWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text("Popular Restaurants", style: Theme.of(context).textTheme.titleLarge),
          )
      );
      suggestionWidgets.addAll(_initialCompanies.map((company) => _buildCompanyTile(company)).toList());
    }

    if (_initialFoods.isNotEmpty) {
      suggestionWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
            child: Text("Popular Dishes", style: Theme.of(context).textTheme.titleLarge),
          )
      );
      suggestionWidgets.addAll(_initialFoods.map((food) => _buildFoodTile(food)).toList());
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: suggestionWidgets,
    );
  }


  Widget _buildSearchResultsList() {
    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];
        if (item is CompanyModel) {
          return _buildCompanyTile(item);
        } else if (item is FoodModel) {
          return _buildFoodTile(item);
        }
        return const SizedBox.shrink(); // Should not happen
      },
    );
  }

  Widget _buildCompanyTile(CompanyModel company) {
    return ListTile(
      leading: (company.logoUrl != null && company.logoUrl!.isNotEmpty && Uri.tryParse(company.logoUrl!)?.hasAbsolutePath == true)
          ? CircleAvatar(
        backgroundImage: NetworkImage(company.logoUrl!),
        onBackgroundImageError: (_, __) {}, // Handle error if needed
        backgroundColor: Colors.grey[200],
      )
          : CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Icon(Icons.business, color: Theme.of(context).colorScheme.onSecondaryContainer),
      ),
      title: Text(company.name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: company.description != null && company.description!.isNotEmpty
          ? Text(company.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
          : null,
      onTap: () => _navigateToCompany(company),
    );
  }

  Widget _buildFoodTile(FoodModel food) {
    // The FoodModel is now expected to have `company` and `companyName` populated if joined.
    final String companyName = food.companyName ?? food.company?.name ?? 'Unknown Restaurant';

    return ListTile(
      leading: (food.imageUrl != null && food.imageUrl!.isNotEmpty && Uri.tryParse(food.imageUrl!)?.hasAbsolutePath == true)
          ? SizedBox(
        width: 50,
        height: 50,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            food.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Container(color: Colors.grey[200], child: const Icon(Icons.fastfood_outlined, color: Colors.grey)),
          ),
        ),
      )
          : Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.fastfood_outlined, color: Colors.grey),
      ),
      title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text("from $companyName - \$${food.price.toStringAsFixed(2)}"),
      onTap: () => _navigateToFoodItem(food),
    );
  }
}
