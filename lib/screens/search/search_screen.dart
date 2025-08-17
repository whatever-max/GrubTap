import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/company_model.dart';
import '../../models/food_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  final supabase = Supabase.instance.client;
  Timer? _debounce;

  List<CompanyModel> _companyResults = [];
  List<FoodModel> _foodResults = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text.trim());
      } else {
        setState(() {
          _companyResults.clear();
          _foodResults.clear();
          _hasSearched = false;
          _errorMessage = null;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasSearched = true;
    });

    try {
      final companyRaw = await supabase
          .from('companies')
          .select()
          .or('name.ilike.%$query%,description.ilike.%$query%')
          .limit(10);

      final foodRaw = await supabase
          .from('foods')
          .select('*, companies (id, name, description, logo_url)')
          .or('name.ilike.%$query%,description.ilike.%$query%')
          .limit(15);

      setState(() {
        _companyResults = companyRaw.map((c) => CompanyModel.fromMap(c)).toList();
        _foodResults = foodRaw.map((f) => FoodModel.fromMap(f)).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() {
        _errorMessage = 'Failed to load search results.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search dishes or restaurants',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear), onPressed: _searchController.clear)
                    : null,
              ),
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_errorMessage != null)
            Expanded(child: Center(child: Text(_errorMessage!)))
          else if (!_hasSearched)
              const Expanded(child: Center(child: Text('Start typing to search')))
            else if (_companyResults.isEmpty && _foodResults.isEmpty)
                const Expanded(child: Center(child: Text('No results found')))
              else
                Expanded(
                  child: ListView(
                    children: [
                      if (_companyResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text('Restaurants', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ..._companyResults.map((c) => ListTile(
                          leading: c.logoUrl != null && c.logoUrl!.isNotEmpty
                              ? CircleAvatar(backgroundImage: NetworkImage(c.logoUrl!))
                              : const CircleAvatar(child: Icon(Icons.restaurant)),
                          title: Text(c.name),
                          subtitle: Text(c.description ?? 'No description'),
                        )),
                      ],
                      if (_foodResults.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Text('Dishes', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        ..._foodResults.map((f) => ListTile(
                          leading: f.imageUrl != null && f.imageUrl!.isNotEmpty
                              ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(f.imageUrl!, width: 50, height: 50, fit: BoxFit.cover),
                          )
                              : const Icon(Icons.fastfood),
                          title: Text(f.name),
                          subtitle: Text(
                              'from ${f.companyName ?? "Unknown"} - \$${f.price.toStringAsFixed(2)}'),
                        )),
                      ],
                    ],
                  ),
                ),
        ],
      ),
    );
  }
}
