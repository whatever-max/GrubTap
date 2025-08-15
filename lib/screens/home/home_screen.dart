// lib/screens/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/banner_model.dart';
 import '../../models/company_model.dart'; // Keep for other uses if any, or remove if only featured_company_model is used for this list
import '../../models/food_model.dart';
import '../../models/featured_company_model.dart'; // Import the new model

import '../../shared/custom_drawer.dart';
import '../../widgets/app_background.dart';

// Screen imports
import '../company/company_list_screen.dart';
import '../company/company_menu_screen.dart'; // Ensure this is the correct screen
import './notifications_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin<HomeScreen> {
  @override
  bool get wantKeepAlive => true;

  final supabase = Supabase.instance.client;
  final ScrollController _scrollController = ScrollController();

  List<BannerModel> _banners = [];
  // Replace _featuredCompanies with _featuredCompanyEntries
  List<FeaturedCompanyModel> _featuredCompanyEntries = [];
  List<FoodModel> _featuredFoods = []; // For the "Popular Dishes" section

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> refreshData() async {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    await _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        supabase.from('banners').select<List<Map<String, dynamic>>>().order('created_at', ascending: false).limit(5),
        // Your new query for featured_companies
        supabase
            .from('featured_companies')
            .select<List<Map<String, dynamic>>>('''
              id,
              highlight_text,
              created_at, 
              companies (
                id,
                name,
                description,
                logo_url,
                created_at 
              ),
              foods (
                id,
                name,
                price,
                image_url,
                company_id, 
                created_at
              )
            ''')
            .order('created_at', ascending: false) // Order by featured_companies.created_at
            .limit(10),
        supabase // For the "Popular Dishes" section (assuming these are globally featured foods)
            .from('foods')
            .select<List<Map<String, dynamic>>>('*, companies(id, name, logo_url)')
        // If you added 'is_featured' to foods table: .eq('is_featured', true)
            .limit(10)
            .order('created_at', ascending: false), // Or some other criteria like popularity
      ]);

      if (mounted) {
        setState(() {
          _banners = (results[0] as List<Map<String, dynamic>>).map((data) => BannerModel.fromMap(data)).toList();
          _featuredCompanyEntries = (results[1] as List<Map<String, dynamic>>)
              .map((data) => FeaturedCompanyModel.fromMap(data))
              .toList();
          _featuredFoods = (results[2] as List<Map<String, dynamic>>).map((data) => FoodModel.fromMap(data)).toList();
          _isLoading = false;
        });
      }
    } on PostgrestException catch (e) {
      debugPrint('Supabase Postgrest Error (HomeScreen): ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load data: ${e.message}. Check connection or RLS policies.';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Unexpected error loading data (HomeScreen): $e \n$stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred.';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchPressed() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen()));
  }

  void _onNotificationsPressed() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  void _goToAllCompanies() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyListScreen()));
  }

  // Update this to use FeaturedCompanyModel
  void _navigateToCompanyMenu(CompanyModel company) {
    if (company.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Company ID is missing.")),
      );
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


  @override
  Widget build(BuildContext context) {
    super.build(context);
    // ... (rest of your build method, AppBar, etc. remains the same) ...
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: const CustomDrawer(),
        appBar: AppBar(
          title: const Text("GrubTap"),
          elevation: 0,
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(icon: const Icon(Icons.search), tooltip: "Search", onPressed: _onSearchPressed),
            IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: "Notifications",
                onPressed: _onNotificationsPressed),
          ],
        ),
        body: _buildBodyContent(),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      // ... (error display remains the same) ...
      return RefreshIndicator(
        onRefresh: refreshData,
        child: ListView( // Wrap in ListView to enable pull-to-refresh even for error
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.7, // Ensure it's scrollable
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
                  const SizedBox(height: 16),
                  Text(_errorMessage!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                      icon: const Icon(Icons.refresh), onPressed: refreshData, label: const Text("Retry")),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Update condition to use _featuredCompanyEntries
    if (_banners.isEmpty && _featuredCompanyEntries.isEmpty && _featuredFoods.isEmpty) {
      // ... (empty content display remains the same, but the condition changed) ...
      return RefreshIndicator(
        onRefresh: refreshData,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.7,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store_mall_directory_outlined, size: 60, color: Colors.grey[500]),
                  const SizedBox(height: 16),
                  Text(
                    "No content available right now.\nPull down to refresh.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refreshData,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        children: [
          if (_banners.isNotEmpty) _buildBannersSection(),
          // Update to use _featuredCompanyEntries
          if (_featuredCompanyEntries.isNotEmpty) _buildFeaturedCompaniesSectionNew(), // Renamed for clarity
          if (_featuredFoods.isNotEmpty) _buildFeaturedFoodsSection(), // This is for "Popular Dishes"
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                onPressed: _goToAllCompanies,
                icon: const Icon(Icons.restaurant_menu_outlined),
                label: const Text("View All Restaurants"),
              ),
            ),
          ),
          const SizedBox(height: 70), // Space for FAB
        ],
      ),
    );
  }

  Widget _buildBannersSection() {
    // ... (this section remains the same) ...
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text("Today's Specials", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 160,
          child: PageView.builder(
            itemCount: _banners.length,
            controller: PageController(viewportFraction: 0.88, initialPage: _banners.length > 1 ? 1 : 0),
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 3,
                child: (banner.imageUrl != null && banner.imageUrl!.isNotEmpty && Uri.tryParse(banner.imageUrl!)?.hasAbsolutePath == true)
                    ? Image.network(
                  banner.imageUrl!,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, loadingProgress) =>
                  loadingProgress == null ? child : const Center(child: CircularProgressIndicator.adaptive()),
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 40, color: Colors.grey)),
                )
                    : Container(color: Colors.grey[200], child: const Center(child: Icon(Icons.image_search_outlined, size: 40, color: Colors.grey))),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // New method to build featured companies using FeaturedCompanyModel
  Widget _buildFeaturedCompaniesSectionNew() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text("Featured Restaurants", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 160, // Adjust height as needed
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _featuredCompanyEntries.length,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemBuilder: (ctx, i) {
              final featuredEntry = _featuredCompanyEntries[i];
              final company = featuredEntry.company; // Get the CompanyModel from the entry

              return SizedBox(
                width: 140, // Adjust width as needed
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  clipBehavior: Clip.antiAlias,
                  elevation: 2,
                  child: InkWell(
                    onTap: () => _navigateToCompanyMenu(company), // Pass the CompanyModel
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (featuredEntry.highlightText != null && featuredEntry.highlightText!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomRight: Radius.circular(6))
                            ),
                            child: Text(
                              featuredEntry.highlightText!,
                              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: (company.logoUrl != null && company.logoUrl!.isNotEmpty && Uri.tryParse(company.logoUrl!)?.hasAbsolutePath == true)
                                ? Image.network(
                              company.logoUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.business_outlined, size: 30, color: Colors.grey)),
                            )
                                : Container(
                                color: Colors.grey[100],
                                child: const Center(child: Icon(Icons.business_outlined, size: 30, color: Colors.grey))),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0),
                          child: Text(
                            company.name,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Optionally, display featured food name if available
                        if (featuredEntry.featuredFood != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              "Try: ${featuredEntry.featuredFood!.name}",
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }


  Widget _buildFeaturedFoodsSection() {
    // This section is for "Popular Dishes" (globally featured foods)
    // It remains largely the same, but ensure it uses _featuredFoods
    // ... (Make sure food.companyName or food.company.name is handled correctly as before) ...
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text("Popular Dishes", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        ),
        SizedBox(
          height: 210,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _featuredFoods.length,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemBuilder: (ctx, i) {
              final food = _featuredFoods[i];
              // Use food.companyName or food.company.name from the FoodModel
              // Ensure your FoodModel's fromMap correctly parses the joined 'companies' data
              final String effectiveCompanyName = food.companyName ?? food.company?.name ?? "Restaurant";

              return SizedBox(
                width: 155,
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                  child: InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tapped on ${food.name} from $effectiveCompanyName")));
                      // Potentially navigate to food details:
                      // if (food.company != null) { // Or if food.companyId is present and you want to fetch company details then
                      //   Navigator.push(context, MaterialPageRoute(builder: (_) => FoodDetailsScreen(food: food, companyId: food.companyId!)));
                      // }
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: (food.imageUrl != null && food.imageUrl!.isNotEmpty && Uri.tryParse(food.imageUrl!)?.hasAbsolutePath == true)
                              ? Image.network(
                            food.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey[100], child: const Center(child: Icon(Icons.fastfood_outlined, size: 30, color: Colors.grey))),
                          )
                              : Container(color: Colors.grey[100], child: const Center(child: Icon(Icons.fastfood_outlined, size: 30, color: Colors.grey))),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                food.name,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                effectiveCompanyName,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "\$${food.price.toStringAsFixed(2)}",
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
