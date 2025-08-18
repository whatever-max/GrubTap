// lib/screens/home/home_screen.dart
import 'dart:async'; // For Timer

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/banner_model.dart';
import '../../models/company_model.dart';
import '../../models/food_model.dart';
import '../../models/featured_company_model.dart';

import '../../shared/custom_drawer.dart';
import '../../widgets/app_background.dart';

// Screen imports
import '../company/company_list_screen.dart';
import '../company/company_menu_screen.dart';
import './notifications_screen.dart';
import '../order/order_now_screen.dart';
import '../food/food_details_screen.dart';

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
  PageController _bannerPageController = PageController();
  Timer? _bannerTimer;
  int _currentBannerPage = 0;

  List<BannerModel> _banners = [];
  List<FeaturedCompanyModel> _featuredCompanyEntries = [];
  List<FoodModel> _featuredFoods = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bannerPageController = PageController(viewportFraction: 0.88, initialPage: 0);
    _loadAllData().then((_) {
      if (mounted && _banners.isNotEmpty) {
        _startBannerAutoScroll();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bannerPageController.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel(); // Cancel any existing timer
    if (!mounted || _banners.length <= 1) return;

    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_currentBannerPage < _banners.length - 1) {
        _currentBannerPage++;
      } else {
        _currentBannerPage = 0;
      }
      if (_bannerPageController.hasClients) {
        _bannerPageController.animateToPage(
          _currentBannerPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<void> refreshData() async {
    if (_scrollController.hasClients && _scrollController.offset > 0) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
    await _loadAllData();
    if (mounted) {
      if (_banners.isNotEmpty) {
        _currentBannerPage = 0; // Reset banner page
        if (_bannerPageController.hasClients) _bannerPageController.jumpToPage(0);
        _startBannerAutoScroll(); // Restart auto-scroll
      } else {
        _bannerTimer?.cancel(); // Stop timer if no banners
      }
    }
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        supabase.from('banners').select().order('created_at', ascending: false).limit(5),
        supabase
            .from('featured_companies')
            .select('''
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
                description,
                created_at
              )
            ''')
            .order('created_at', ascending: false)
            .limit(10),
        supabase
            .from('foods')
            .select('*, companies(id, name, logo_url)')
            .limit(10)
            .order('created_at', ascending: false),
      ]);

      if (!mounted) return;

      final bannerData = results[0] as List<dynamic>;
      final featuredCompanyData = results[1] as List<dynamic>;
      final featuredFoodData = results[2] as List<dynamic>;

      setState(() {
        _banners = bannerData.map((data) => BannerModel.fromMap(data as Map<String, dynamic>)).toList();

        // This assumes your FeaturedCompanyModel.fromMap is now structured
        // to correctly create its FoodModel (featuredFood) with the necessary
        // company context passed to FoodModel.fromMap.
        _featuredCompanyEntries = featuredCompanyData.map((data) {
          return FeaturedCompanyModel.fromMap(data as Map<String, dynamic>);
        }).toList();

        _featuredFoods = featuredFoodData.map((data) => FoodModel.fromMap(data as Map<String, dynamic>)).toList();

        _isLoading = false;
      });

    } on PostgrestException catch (e) {
      debugPrint('Supabase Postgrest Error (HomeScreen): ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load data. Please check your connection and try again. (${e.code})';
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Unexpected error loading data (HomeScreen): $e \n$stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchPressed() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyListScreen(isSearchFocused: true)));
  }

  void _onNotificationsPressed() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  void _goToAllCompanies() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyListScreen()));
  }

  void _navigateToCompanyMenu(CompanyModel company) {
    if (company.id.isEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Company ID is missing.")),
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

  void _navigateToFoodDetails(FoodModel food) {
    // food.company should be populated by FoodModel.fromMap if data structure is correct.
    // food.companyName can also be a fallback.
    if (food.company == null && (food.companyId == null || food.companyName == null || food.companyName!.isEmpty)) {
      debugPrint("Navigating to FoodDetails for food ID ${food.id}. Company details might be missing or only partially available (ID: ${food.companyId}, Name: ${food.companyName}).");
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FoodDetailsScreen(food: food),
      ),
    );
  }

  void _navigateToOrderNowForBanner(BannerModel banner) {
    // Placeholder - implement actual navigation or action
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OrderNowScreen()), // Example
    );
  }


  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: const CustomDrawer(),
        appBar: AppBar(
          title: Text("GrubTap", style: TextStyle(color: theme.colorScheme.onPrimaryContainer)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          iconTheme: IconThemeData(color: theme.colorScheme.onPrimaryContainer),
          actionsIconTheme: IconThemeData(color: theme.colorScheme.onPrimaryContainer),
          actions: [
            IconButton(icon: const Icon(Icons.search), tooltip: "Search Restaurants", onPressed: _onSearchPressed),
            IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: "Notifications",
                onPressed: _onNotificationsPressed),
          ],
        ),
        body: _buildBodyContent(theme),
      ),
    );
  }

  Widget _buildBodyContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (_errorMessage != null) {
      return RefreshIndicator(
        onRefresh: refreshData,
        child: LayoutBuilder( // Use LayoutBuilder to ensure ListView has bounded height for AlwaysScrollableScrollPhysics
            builder: (context, constraints) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Container(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight), // Make container fill screen
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 50),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.errorContainer,
                              foregroundColor: theme.colorScheme.onErrorContainer,
                            ),
                            icon: const Icon(Icons.refresh), onPressed: refreshData, label: const Text("Retry")),
                      ],
                    ),
                  ),
                ],
              );
            }
        ),
      );
    }

    if (_banners.isEmpty && _featuredCompanyEntries.isEmpty && _featuredFoods.isEmpty) {
      return RefreshIndicator(
        onRefresh: refreshData,
        child: LayoutBuilder( // Use LayoutBuilder for empty state as well
            builder: (context, constraints) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Container(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.store_mall_directory_outlined, size: 60, color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
                        const SizedBox(height: 16),
                        Text(
                          "No content available right now.\nPull down to refresh.",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(color: theme.textTheme.bodyMedium?.color?.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: refreshData,
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 70), // Padding for potential nav bar + general spacing
        children: [
          if (_banners.isNotEmpty) _buildBannersSection(theme),
          if (_featuredFoods.isNotEmpty || _featuredCompanyEntries.isNotEmpty)
            _buildPopularItemsAndRestaurantsSection(theme),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: theme.textTheme.labelLarge,
                ),
                onPressed: _goToAllCompanies,
                icon: const Icon(Icons.restaurant_menu_outlined),
                label: const Text("View All Restaurants"),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildBannersSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            "Today's Specials",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onBackground,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _bannerPageController,
            itemCount: _banners.length,
            onPageChanged: (int page) {
              if(mounted) {
                setState(() {
                  _currentBannerPage = page;
                });
              }
            },
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return GestureDetector(
                onTap: () => _navigateToOrderNowForBanner(banner),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (banner.imageUrl != null &&
                          banner.imageUrl!.isNotEmpty &&
                          Uri.tryParse(banner.imageUrl!)?.hasAbsolutePath == true)
                        Image.network(
                          banner.imageUrl!,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, loadingProgress) =>
                          loadingProgress == null ? child : const Center(child: CircularProgressIndicator.adaptive()),
                          errorBuilder: (_, __, ___) => Container(
                            color: theme.highlightColor.withOpacity(0.5),
                            child: Center(child: Icon(Icons.broken_image_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant)),
                          ),
                        )
                      else
                        Container(
                          color: theme.highlightColor.withOpacity(0.5),
                          child: Center(child: Icon(Icons.image_search_outlined, size: 40, color: theme.colorScheme.onSurfaceVariant)),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_banners.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_banners.length, (index) {
              return Container(
                width: 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentBannerPage == index
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              );
            }),
          ),
        const SizedBox(height: 16),
      ],
    );
  }


  Widget _buildPopularItemsAndRestaurantsSection(ThemeData theme) {
    double screenWidth = MediaQuery.of(context).size.width;
    double foodItemWidth = screenWidth > 600 ? screenWidth / 3.5 : screenWidth / 2.3; // Responsive width
    double companyItemWidth = screenWidth > 600 ? screenWidth / 4.2 : screenWidth / 2.7; // Responsive width

    return Column(
      children: [
        if (_featuredFoods.isNotEmpty)
          _buildHorizontalListSection(
            theme: theme,
            title: "Popular Dishes",
            itemCount: _featuredFoods.length,
            itemBuilder: (ctx, i) {
              final food = _featuredFoods[i];
              // food.company should be populated by '*, companies(*)' in _loadAllData for _featuredFoods
              final String effectiveCompanyName = food.company?.name ?? food.companyName ?? "Restaurant";
              return SizedBox(
                width: foodItemWidth,
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                  child: InkWell(
                    onTap: () => _navigateToFoodDetails(food),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: (food.imageUrl != null &&
                              food.imageUrl!.isNotEmpty &&
                              Uri.tryParse(food.imageUrl!)?.hasAbsolutePath == true)
                              ? Image.network(
                            food.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: theme.highlightColor.withOpacity(0.3),
                                child: Center(child: Icon(Icons.fastfood_outlined, size: 30, color: theme.colorScheme.onSurfaceVariant))),
                          )
                              : Container(
                              color: theme.highlightColor.withOpacity(0.3),
                              child: Center(child: Icon(Icons.fastfood_outlined, size: 30, color: theme.colorScheme.onSurfaceVariant))),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                food.name,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                effectiveCompanyName,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "\$${food.price.toStringAsFixed(2)}",
                                style: theme.textTheme.titleSmall?.copyWith(
                                    color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
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
            listHeight: 230,
          ),

        if (_featuredCompanyEntries.isNotEmpty)
          _buildHorizontalListSection(
            theme: theme,
            title: "Featured Restaurants",
            itemCount: _featuredCompanyEntries.length,
            itemBuilder: (ctx, i) {
              final featuredEntry = _featuredCompanyEntries[i];
              final company = featuredEntry.company; // This is CompanyModel

              return SizedBox(
                width: companyItemWidth,
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  clipBehavior: Clip.antiAlias,
                  elevation: 2,
                  child: InkWell(
                    onTap: () => _navigateToCompanyMenu(company),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (featuredEntry.highlightText != null && featuredEntry.highlightText!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer.withOpacity(0.8),
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), bottomRight: Radius.circular(8))
                            ),
                            child: Text(
                              featuredEntry.highlightText!,
                              style: TextStyle(color: theme.colorScheme.onSecondaryContainer, fontSize: 10, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Expanded(
                          flex: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(10.0), // More padding for logo
                            child: (company.logoUrl != null &&
                                company.logoUrl!.isNotEmpty &&
                                Uri.tryParse(company.logoUrl!)?.hasAbsolutePath == true)
                                ? Image.network(
                              company.logoUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Center(child: Icon(Icons.business_outlined, size: 30, color: theme.colorScheme.onSurfaceVariant)),
                            )
                                : Container(
                                color: theme.highlightColor.withOpacity(0.2), // Lighter background for placeholder
                                child: Center(child: Icon(Icons.business_outlined, size: 30, color: theme.colorScheme.onSurfaceVariant))),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 4.0), // Adjust padding
                          child: Text(
                            company.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2, // Allow two lines for company name
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (featuredEntry.featuredFood != null)
                          GestureDetector(
                            onTap: () {
                              if (featuredEntry.featuredFood != null) {
                                // featuredEntry.featuredFood.company should be populated by FeaturedCompanyModel.fromMap
                                _navigateToFoodDetails(featuredEntry.featuredFood!);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0),
                              child: Text(
                                "Try: ${featuredEntry.featuredFood!.name}",
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.tertiary),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        if (featuredEntry.featuredFood == null) const SizedBox(height: 12), // Placeholder if no food
                      ],
                    ),
                  ),
                ),
              );
            },
            listHeight: 210, // Adjust height as needed
          ),
      ],
    );
  }

  Widget _buildHorizontalListSection({
    required ThemeData theme,
    required String title,
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    required double listHeight,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 10), // Adjusted padding
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onBackground,
            ),
          ),
        ),
        SizedBox(
          height: listHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: itemCount,
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            itemBuilder: itemBuilder,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
