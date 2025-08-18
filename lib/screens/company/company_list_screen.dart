// lib/screens/company/company_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/company_model.dart';
import '../company/company_menu_screen.dart'; // Ensure this is imported for navigation
import '../../widgets/app_background.dart'; // Optional: if you want a consistent app background

class CompanyListScreen extends StatefulWidget {
  final bool isSearchFocused; // To auto-focus search if coming from search icon

  const CompanyListScreen({
    super.key,
    this.isSearchFocused = false,
  });

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  final supabase = Supabase.instance.client;
  List<CompanyModel> _allCompanies = [];
  List<CompanyModel> _filteredCompanies = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _searchTerm = '';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchAllCompanies();
    _searchController.addListener(_onSearchChanged);
    if (widget.isSearchFocused) {
      // Request focus after the first frame is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_searchFocusNode);
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchAllCompanies({bool isRetry = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      if (isRetry) _errorMessage = null; // Clear error on retry
    });

    try {
      final List<Map<String, dynamic>> data = await supabase
          .from('companies')
          .select() // Select all needed fields
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _allCompanies = data.map((item) => CompanyModel.fromMap(item)).toList();
          _filterCompanies(); // Apply initial filter (which might be empty search)
          _isLoading = false;
        });
      }
    } on PostgrestException catch (e) {
      debugPrint('Supabase Error (CompanyListScreen): ${e.message}');
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load restaurants: ${e.message}";
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Unexpected Error (CompanyListScreen): $e\n$stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = "An unexpected error occurred while loading restaurants.";
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _searchTerm = _searchController.text;
        _filterCompanies();
      });
    });
  }

  void _filterCompanies() {
    if (_searchTerm.isEmpty) {
      _filteredCompanies = List.from(_allCompanies);
    } else {
      _filteredCompanies = _allCompanies
          .where((company) =>
      company.name.toLowerCase().contains(_searchTerm.toLowerCase()) ||
          (company.description?.toLowerCase().contains(_searchTerm.toLowerCase()) ?? false))
          .toList();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    // _onSearchChanged will be triggered by the listener,
    // or call setState directly if not relying on listener for empty string
    if (mounted) {
      setState(() {
        _searchTerm = '';
        _filterCompanies();
      });
    }
    _searchFocusNode.unfocus(); // Unfocus keyboard
  }

  void _navigateToCompanyMenu(CompanyModel company) {
    if (company.id.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Company ID is missing. Cannot open menu.")),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppBackground( // Optional: for consistent background
      child: Scaffold(
        backgroundColor: Colors.transparent, // If using AppBackground
        // backgroundColor: theme.colorScheme.background, // Standard background
        appBar: AppBar(
          title: Text(
            'All Restaurants',
            style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
          ),
          backgroundColor: Colors.transparent, // Or theme.appBarTheme.backgroundColor
          elevation: 0,
          iconTheme: IconThemeData(color: theme.colorScheme.onPrimaryContainer),
        ),
        body: Column(
          children: [
            _buildSearchBar(theme),
            Expanded(child: _buildCompanyList(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search restaurants by name or description...',
          hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
          suffixIcon: _searchTerm.isNotEmpty
              ? IconButton(
            icon: Icon(Icons.clear, color: theme.colorScheme.onSurfaceVariant),
            onPressed: _clearSearch,
          )
              : null,
          filled: true,
          fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25.0),
            borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
          ),
        ),
        style: TextStyle(color: theme.colorScheme.onSurface),
        // onChanged: (value) => _onSearchChanged(), // Listener already handles this
      ),
    );
  }

  Widget _buildCompanyList(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error),
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
                onPressed: () => _fetchAllCompanies(isRetry: true),
              )
            ],
          ),
        ),
      );
    }

    if (_allCompanies.isEmpty) { // Check original list for this message
      return Center(
        child: Text(
          'No restaurants found.',
          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    if (_filteredCompanies.isEmpty && _searchTerm.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'No restaurants found for "$_searchTerm".',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16.0, left: 8.0, right: 8.0),
      itemCount: _filteredCompanies.length,
      itemBuilder: (context, index) {
        final company = _filteredCompanies[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          color: theme.cardColor,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            leading: (company.logoUrl != null &&
                company.logoUrl!.isNotEmpty &&
                Uri.tryParse(company.logoUrl!)?.hasAbsolutePath == true)
                ? CircleAvatar(
              radius: 28,
              backgroundImage: NetworkImage(company.logoUrl!),
              onBackgroundImageError: (_, __) {}, // Optional: Handle image load error more gracefully
              backgroundColor: theme.highlightColor, // Placeholder color
            )
                : CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.secondaryContainer,
              child: Icon(Icons.business, color: theme.colorScheme.onSecondaryContainer, size: 28),
            ),
            title: Text(
              company.name,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
            ),
            subtitle: Text(
              company.description ?? 'No description available.',
              maxLines: 2, // Allow a bit more for description
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            trailing: Icon(Icons.chevron_right, color: theme.colorScheme.outline),
            onTap: () => _navigateToCompanyMenu(company),
          ),
        );
      },
    );
  }
}

