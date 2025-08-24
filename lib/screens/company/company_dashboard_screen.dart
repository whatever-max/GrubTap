// lib/screens/company/company_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:grubtap/services/session_service.dart';
import 'package:grubtap/shared/custom_drawer.dart';

// --- Screen Imports for Navigation ---
import 'manage_foods_screen.dart';
import 'company_orders_screen.dart'; // <<<<<<< 1. ENSURE THIS IS UNCOMMENTED AND FILE EXISTS

class CompanyDashboardScreen extends StatefulWidget {
  static const String routeName = '/company-dashboard';

  const CompanyDashboardScreen({super.key});

  @override
  State<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends State<CompanyDashboardScreen> {
  String? _currentUserRole;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    final role = SessionService.getCachedUserRole();
    if (mounted) {
      setState(() {
        _currentUserRole = role;
      });
    }
  }

  void _navigateToManageMenu(BuildContext context) {
    Navigator.pushNamed(context, ManageFoodsScreen.routeName);
    debugPrint("[CompanyDashboardScreen] Navigating to Manage Menu: ${ManageFoodsScreen.routeName}");
  }

  void _navigateToViewOrders(BuildContext context) {
    // <<<<<<< 2. USE THE DEFINED routeName FROM THE IMPORTED SCREEN
    Navigator.pushNamed(context, CompanyOrdersScreen.routeName);
    debugPrint("[CompanyDashboardScreen] Navigating to View Orders: ${CompanyOrdersScreen.routeName}");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Company Dashboard', style: TextStyle(color: theme.appBarTheme.foregroundColor)),
      ),
      drawer: CustomDrawer(userRole: _currentUserRole ?? 'company'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            Icon(Icons.storefront_outlined, size: 80, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Welcome, Company Representative!',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (_currentUserRole != null)
              Padding(
                padding: const EdgeInsets.only(top: 4.0, bottom: 24.0),
                child: Text('Your Role: $_currentUserRole', style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
              ),
            const SizedBox(height: 20),
            _buildDashboardButton(
              context: context,
              icon: Icons.restaurant_menu,
              label: 'Manage Menu',
              onTap: () => _navigateToManageMenu(context),
            ),
            const SizedBox(height: 16),
            _buildDashboardButton(
              context: context,
              icon: Icons.receipt_long,
              label: 'View Orders',
              onTap: () => _navigateToViewOrders(context),
            ),
            const SizedBox(height: 30),
            Text(
              'Use the options above to manage your food items and view incoming customer orders.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ElevatedButton.icon(
      icon: Icon(icon, size: 28),
      label: Text(label),
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
      ).copyWith(
        elevation: MaterialStateProperty.all(2),
      ),
    );
  }
}

