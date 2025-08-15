// lib/screens/order/company_details_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import '../../models/company_model.dart';
import '../../models/food_model.dart';
import './order_screen.dart';

// Convert to StatefulWidget to manage loading and data fetching state
class CompanyDetailsScreen extends StatefulWidget {
  final CompanyModel company;

  const CompanyDetailsScreen({
    super.key,
    required this.company,
  });

  @override
  State<CompanyDetailsScreen> createState() => _CompanyDetailsScreenState();
}

class _CompanyDetailsScreenState extends State<CompanyDetailsScreen> {
  List<FoodModel> _companyFoods = [];
  bool _isLoading = true;
  String? _errorMessage;
  final _supabase = Supabase.instance.client; // Supabase client instance

  @override
  void initState() {
    super.initState();
    // Fetch foods when the screen initializes
    _fetchFoodsForCompany();
  }

  Future<void> _fetchFoodsForCompany() async {
    if (!mounted) return; // Check if the widget is still in the tree

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Fetch foods from the 'foods' table where 'company_id' matches widget.company.id
      // The select query can be adjusted if you need specific columns or joined data from 'companies' table
      // For now, let's select all columns from 'foods' for simplicity.
      // If you also want to fetch company details along with each food (like company name):
      // .select('*, companies(id, name, logo_url)')
      // However, since we already have widget.company, we might not need to join here unless FoodModel
      // specifically needs the nested company object from the food query itself.
      // Your FoodModel.fromMap already handles a nested 'companies' map.
      final response = await _supabase
          .from('foods')
          .select<List<Map<String, dynamic>>>() // Ensure type for Supabase query
          .eq('company_id', widget.company.id)
          .order('created_at', ascending: false); // Optional: order by creation date or name

      if (!mounted) return; // Check again after await

      // Parse the response into a list of FoodModel objects
      _companyFoods = response.map((data) => FoodModel.fromMap(data)).toList();

      setState(() {
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      debugPrint('Supabase Error fetching foods: ${error.message}');
      setState(() {
        _errorMessage = 'Failed to load food items: ${error.message}';
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      debugPrint('Unexpected Error fetching foods: $error');
      setState(() {
        _errorMessage = 'An unexpected error occurred.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.company.name)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
              Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _fetchFoodsForCompany, // Retry button
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              )
            ],
          ),
        ),
      );
    }

    if (_companyFoods.isEmpty) {
      return const Center(child: Text('No food items available for this company yet.'));
    }

    return ListView.builder(
      itemCount: _companyFoods.length,
      itemBuilder: (context, index) {
        final food = _companyFoods[index];
        final imageUrl = food.imageUrl;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          elevation: 2,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: SizedBox(
              width: 60,
              height: 60,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: (imageUrl != null && imageUrl.isNotEmpty && Uri.tryParse(imageUrl)?.hasAbsolutePath == true)
                    ? Image.network(
                  imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image_outlined, size: 30, color: Colors.grey),
                    );
                  },
                  loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                )
                    : Container(
                  color: Colors.grey[200],
                  child: const Icon(Icons.fastfood_outlined, size: 30, color: Colors.grey),
                ),
              ),
            ),
            title: Text(food.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${food.price.toStringAsFixed(2)} USD\n${food.description}', // food.description is already defaulted to '' in model
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            isThreeLine: food.description.isNotEmpty,
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OrderScreen(
                    food: food,
                    company: widget.company, // Pass the original company object
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
// No need for _getSampleFoodsForCompany anymore!
}
