// lib/screens/company/company_list_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/company_model.dart';
// import '../company/company_menu_screen.dart'; // Uncomment if you use it for navigation

class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({super.key});

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  final supabase = Supabase.instance.client;
  List<CompanyModel> _allCompanies = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAllCompanies();
  }

  Future<void> _fetchAllCompanies() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Corrected: Removed explicit type argument from .select()
      // The .select() directly returns List<Map<String, dynamic>> or throws PostgrestException.
      final List<Map<String, dynamic>> data = await supabase
          .from('companies')
          .select() // Corrected
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _allCompanies = data.map((item) => CompanyModel.fromMap(item)).toList();
          _isLoading = false;
        });
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Failed to load companies: ${e.message}";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "An unexpected error occurred.";
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToCompanyMenu(CompanyModel company) {
    // If you have CompanyMenuScreen and want to navigate:
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => CompanyMenuScreen( // Ensure CompanyMenuScreen is imported
    //       companyId: company.id,
    //       companyName: company.name,
    //     ),
    //   ),
    // );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Tapped ${company.name}")));
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Restaurants')),
      body: _buildCompanyList(),
    );
  }

  Widget _buildCompanyList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text("Retry"),
                onPressed: _fetchAllCompanies,
              )
            ],
          ),
        ),
      );
    }
    if (_allCompanies.isEmpty) {
      return const Center(child: Text('No restaurants found.'));
    }
    return ListView.builder(
      itemCount: _allCompanies.length,
      itemBuilder: (context, index) {
        final company = _allCompanies[index];
        return ListTile(
          leading: (company.logoUrl != null && company.logoUrl!.isNotEmpty && Uri.tryParse(company.logoUrl!)?.hasAbsolutePath == true)
              ? CircleAvatar(
            backgroundImage: NetworkImage(company.logoUrl!),
            onBackgroundImageError: (_, __) {}, // Optional: Handle error
            backgroundColor: Colors.grey[200], // Placeholder color
          )
              : CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            child: Icon(Icons.business, color: Theme.of(context).colorScheme.onSecondaryContainer),
          ),
          title: Text(company.name),
          subtitle: Text(company.description ?? 'No description.', maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _navigateToCompanyMenu(company),
        );
      },
    );
  }
}

