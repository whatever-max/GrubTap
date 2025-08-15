// lib/screens/company/company_list_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/company_model.dart';
// import 'company_menu_screen.dart'; // For navigation

class CompanyListScreen extends StatefulWidget {
  // Constructor no longer requires 'companies'
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
      final data = await supabase
          .from('companies')
          .select<List<Map<String, dynamic>>>()
          .order('name', ascending: true); // Or any other order

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
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (_) => CompanyMenuScreen(
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
          child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
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
          leading: company.logoUrl != null && company.logoUrl!.isNotEmpty
              ? CircleAvatar(backgroundImage: NetworkImage(company.logoUrl!))
              : const CircleAvatar(child: Icon(Icons.business)),
          title: Text(company.name),
          subtitle: Text(company.description ?? 'No description.', maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () => _navigateToCompanyMenu(company),
        );
      },
    );
  }
}
