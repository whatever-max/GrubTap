// lib/screens/admin/admin_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:grubtap/services/session_service.dart';
import 'package:grubtap/shared/custom_drawer.dart';
import 'package:grubtap/utils/string_extensions.dart';
// --- Screen Imports ---
import 'package:grubtap/screens/admin/admin_invite_user_screen.dart';
import 'package:grubtap/screens/admin/admin_permissions_screen.dart';
import 'package:grubtap/screens/admin/management/admin_manage_users_screen.dart';      // <<< IMPORTED
import 'package:grubtap/screens/admin/management/admin_manage_companies_screen.dart'; // <<< IMPORTED
import 'package:grubtap/screens/admin/management/admin_manage_foods_screen.dart';    // <<< IMPORTED
import 'package:grubtap/screens/admin/management/admin_manage_orders_screen.dart';   // <<< IMPORTED
import 'package:grubtap/screens/admin/admin_analytics_screen.dart';                  // <<< IMPORTED


class AdminDashboardScreen extends StatefulWidget {
  static const String routeName = '/admin-dashboard';
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String? _currentUserRole;
  String? _currentUserEmail;

  bool get _isSuperAdmin => _currentUserEmail == 'fiqraadmin@gmail.com';

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
  }

  Future<void> _fetchUserDetails() async {
    final role = SessionService.getCachedUserRole();
    final email = SessionService.getCurrentUser()?.email;
    if (mounted) {
      setState(() {
        _currentUserRole = role;
        _currentUserEmail = email;
      });
    }
  }

  void _navigateTo(BuildContext context, String routeName, {bool superAdminOnly = false}) {
    if (superAdminOnly && !_isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Access Denied: Super Administrator role required.')),
      );
      return;
    }
    Navigator.pushNamed(context, routeName);
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool requiresSuperAdmin = false,
    // bool initiallyEnabled = true, // Not currently used, but kept for potential future use
  }) {
    final theme = Theme.of(context);
    final bool canAccess = (requiresSuperAdmin && _isSuperAdmin) || !requiresSuperAdmin;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: canAccess ? onTap : () {
          // This specific onTap for !canAccess will only trigger if requiresSuperAdmin is true and user is not _isSuperAdmin
          // because if !requiresSuperAdmin, canAccess is true.
          if (requiresSuperAdmin && !_isSuperAdmin) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Access Denied: Super Administrator role required.')),
            );
          }
          // If a card is generally not accessible for other reasons (e.g. a feature flag, not just superAdmin)
          // that logic would be handled by the onTap directly or by disabling the card further.
        },
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: canAccess ? 1.0 : 0.6, // Dim if not accessible due to superAdmin requirement
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: canAccess ? theme.colorScheme.primary : Colors.grey.shade700),
                const SizedBox(height: 12),
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(subtitle, style: theme.textTheme.bodySmall, textAlign: TextAlign.center),
                if (requiresSuperAdmin && !_isSuperAdmin) // Show '(Super Admin Only)' only if it's required BUT user isn't SA
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text('(Super Admin Only)', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.error)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard', style: TextStyle(color: theme.appBarTheme.foregroundColor)),
      ),
      drawer: CustomDrawer(userRole: _currentUserRole ?? 'admin'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${_isSuperAdmin ? "Super Administrator" : (_currentUserRole?.capitalizeFirst() ?? "Administrator")}!', // Use capitalizeFirst from string_extensions
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_currentUserEmail != null)
              Padding(
                padding: const EdgeInsets.only(top: 2.0, bottom: 16.0),
                child: Text('Logged in as: $_currentUserEmail', style: theme.textTheme.bodySmall),
              ),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 750 ? 3 : (MediaQuery.of(context).size.width > 500 ? 2 : 1), // Responsive columns
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: MediaQuery.of(context).size.width > 500 ? 1.1 : 1.4, // Adjust aspect ratio for better look on small screens
              children: [
                // User Invitation
                _buildDashboardCard(
                  context: context,
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'User Invitation',
                  subtitle: 'Invite or add new users to the system.',
                  onTap: () => _navigateTo(context, AdminInviteUserScreen.routeName, superAdminOnly: true), // Typically Super Admin or specific invite perm
                  requiresSuperAdmin: true, // Let's keep this SA only for now from dashboard
                ),
                // Permissions Management
                _buildDashboardCard(
                  context: context,
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Permissions Mgt.',
                  subtitle: 'Grant/revoke permissions for other admins.',
                  onTap: () => _navigateTo(context, AdminPermissionsScreen.routeName, superAdminOnly: true),
                  requiresSuperAdmin: true,
                ),
                // Manage All Users
                _buildDashboardCard(
                  context: context,
                  icon: Icons.manage_accounts_outlined,
                  title: 'Manage Users',
                  subtitle: 'Browse and manage all user accounts.',
                  onTap: () => _navigateTo(context, AdminManageUsersScreen.routeName, superAdminOnly: false), // SuperAdmin can, other admins if they have MANAGE_USERS permission
                  // requiresSuperAdmin: true, // The screen itself will check general MANAGE_USERS perm
                  // We make it accessible if user is SA or has general perm to view users.
                  // Actual editing/deleting is controlled by finer perms or SA.
                  // For the dashboard card, SA only.
                  requiresSuperAdmin: true,
                ),
                // Manage Companies
                _buildDashboardCard(
                  context: context,
                  icon: Icons.business_center_outlined,
                  title: 'Manage Companies',
                  subtitle: 'Browse and manage company profiles.',
                  onTap: () => _navigateTo(context, AdminManageCompaniesScreen.routeName, superAdminOnly: true),
                  requiresSuperAdmin: true,
                ),
                // Manage Foods
                _buildDashboardCard(
                  context: context,
                  icon: Icons.restaurant_menu_outlined,
                  title: 'Manage All Foods',
                  subtitle: 'Oversee all food items in the system.',
                  onTap: () => _navigateTo(context, AdminManageFoodsScreen.routeName, superAdminOnly: true),
                  requiresSuperAdmin: true,
                ),
                // Manage Orders
                _buildDashboardCard(
                  context: context,
                  icon: Icons.receipt_long_outlined,
                  title: 'Manage All Orders',
                  subtitle: 'Monitor all system orders and statuses.',
                  onTap: () => _navigateTo(context, AdminManageOrdersScreen.routeName, superAdminOnly: true),
                  requiresSuperAdmin: true,
                ),
                // System Analytics (Full Width Card below Grid)
              ],
            ),
            const SizedBox(height: 20),
            // System Analytics (Potentially accessible by more admins)
            _buildDashboardCard(
              context: context,
              icon: Icons.analytics_outlined,
              title: 'System Analytics',
              subtitle: 'View summaries of users, companies, sales.',
              onTap: () => _navigateTo(context, AdminAnalyticsScreen.routeName, superAdminOnly: false), // Let VIEW_ANALYTICS perm control access
              // requiresSuperAdmin: false, // The AnalyticsScreen itself will check permissions
            ),
          ],
        ),
      ),
    );
  }
}
