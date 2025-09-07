// lib/screens/admin/admin_dashboard_screen.dart
import 'dart:async'; // Added for Timer
import 'package:flutter/foundation.dart'; // <<< Ensure this is imported for describeEnum
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for Clipboard
import 'package:grubtap/models/order_model.dart'; // Make sure this path is correct
import 'package:grubtap/services/session_service.dart';
import 'package:grubtap/shared/custom_drawer.dart';
import 'package:grubtap/utils/string_extensions.dart';
import 'package:intl/intl.dart'; // Added for date/time formatting
import 'package:supabase_flutter/supabase_flutter.dart'; // Added for Supabase client

// --- Screen Imports ---
import 'package:grubtap/screens/admin/admin_invite_user_screen.dart';
import 'package:grubtap/screens/admin/admin_permissions_screen.dart';
import 'package:grubtap/screens/admin/management/admin_manage_users_screen.dart';
import 'package:grubtap/screens/admin/management/admin_manage_companies_screen.dart';
import 'package:grubtap/screens/admin/management/admin_manage_foods_screen.dart';
import 'package:grubtap/screens/admin/management/admin_manage_orders_screen.dart';
import 'package:grubtap/screens/admin/admin_analytics_screen.dart';

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

  // --- State for Daily Order Summary ---
  List<OrderModel> _summaryOrders = [];
  String _editableFloorNumber = "06"; // Default floor number
  final TextEditingController _floorController = TextEditingController();
  Timer? _summaryTimer;
  final supabase = Supabase.instance.client; // Supabase client

  final TimeOfDay _summaryCycleStartMarker = const TimeOfDay(hour: 15, minute: 31); // 3:31 PM
  final TimeOfDay _summaryCycleEndMarker = const TimeOfDay(hour: 15, minute: 29);   // 3:29 PM (next day)
  final String _summaryOrderStatusString = "sent";
  String _currentSummaryPeriodDisplay = "";
  // --- End State for Daily Order Summary ---

  @override
  void initState() {
    super.initState();
    _fetchUserDetails();
    _floorController.text = _editableFloorNumber;
    _setupSummaryTimer();
  }

  @override
  void dispose() {
    _summaryTimer?.cancel();
    _floorController.dispose();
    super.dispose();
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

  // --- Methods for Daily Order Summary ---
  void _setupSummaryTimer() {
    _summaryTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _determinePeriodAndFetchData();
    });
    _determinePeriodAndFetchData();
  }

  Map<String, DateTime> _getRelevantSummaryPeriod(DateTime now) {
    DateTime relevantPeriodStart;
    DateTime relevantPeriodEnd;
    DateTime todayCycleStartBoundary = DateTime(now.year, now.month, now.day, _summaryCycleStartMarker.hour, _summaryCycleStartMarker.minute);

    if (now.isBefore(todayCycleStartBoundary)) {
      relevantPeriodStart = DateTime(now.year, now.month, now.day - 1, _summaryCycleStartMarker.hour, _summaryCycleStartMarker.minute);
      relevantPeriodEnd = DateTime(now.year, now.month, now.day, _summaryCycleEndMarker.hour, _summaryCycleEndMarker.minute);
    } else {
      relevantPeriodStart = todayCycleStartBoundary;
      relevantPeriodEnd = DateTime(now.year, now.month, now.day + 1, _summaryCycleEndMarker.hour, _summaryCycleEndMarker.minute);
    }
    return {'start': relevantPeriodStart, 'end': relevantPeriodEnd};
  }

  void _determinePeriodAndFetchData() {
    final now = DateTime.now();
    final period = _getRelevantSummaryPeriod(now);
    final DateTime periodStart = period['start']!;
    final DateTime periodEnd = period['end']!;
    final DateFormat formatter = DateFormat('MMM d (h:mm a)');

    if (mounted) {
      setState(() {
        _currentSummaryPeriodDisplay = "Summary Period: ${formatter.format(periodStart)} - ${formatter.format(periodEnd)}";
      });
    }

    if (now.isBefore(periodEnd)) {
      _fetchSummaryOrdersForPeriod(periodStart, periodEnd);
    } else {
      if (mounted && _summaryOrders.isNotEmpty) {
        setState(() {
          _summaryOrders = [];
        });
        debugPrint("Summary data cleared as current time is past the period end: ${formatter.format(periodEnd)}");
      } else if (mounted) {
        debugPrint("Current time is past period end: ${formatter.format(periodEnd)}. Waiting for next cycle.");
      }
    }
  }

  Future<void> _fetchSummaryOrdersForPeriod(DateTime periodStart, DateTime periodEnd) async {
    try {
      final response = await supabase
          .from('orders')
          .select('*, order_items(*, foods(id, name)), companies(name)')
          .eq('status', _summaryOrderStatusString)
          .gte('order_time', periodStart.toUtc().toIso8601String())
          .lte('order_time', periodEnd.toUtc().toIso8601String())
          .order('order_time', ascending: false);
      final List<OrderModel> fetchedOrders = response.map((data) => OrderModel.fromMap(data as Map<String, dynamic>)).toList();
      if (mounted) {
        setState(() => _summaryOrders = fetchedOrders);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error fetching summary: ${e.toString()}')));
        setState(() => _summaryOrders = []);
      }
      debugPrint("Error fetching summary orders for period: $e");
    }
  }

  String _formatQuantity(int quantity) {
    return quantity.toString().padLeft(2, '0');
  }

  String _buildSummaryTextForClipboard() {
    String companyName = "N/A Company"; // Default
    if (_summaryOrders.isNotEmpty) {
      if (_summaryOrders.first.companyName != null && _summaryOrders.first.companyName!.isNotEmpty) {
        if (_summaryOrders.every((order) => order.companyName == _summaryOrders.first.companyName)) {
          companyName = _summaryOrders.first.companyName!;
        } else {
          companyName = "Multiple Companies"; // If different companies are present
        }
      } else if (_summaryOrders.map((o) => o.companyName).toSet().length > 1 && _summaryOrders.any((o)=> o.companyName != null && o.companyName!.isNotEmpty) ) {
        // This case handles if there are multiple distinct non-null company names
        companyName = "Multiple Companies";
      }
      // If all company names are null or empty, it remains "N/A Company"
    }


    StringBuffer sb = StringBuffer();
    // Line 1: Company and Floor
    sb.writeln("$companyName - floors ya $_editableFloorNumber");
    sb.writeln(); // Blank line

    if (_summaryOrders.isEmpty) {
      sb.writeln("No orders for the current summary period.");
      sb.writeln("Jumla: 00");
      return sb.toString();
    }

    Map<String, int> aggregatedItems = {};
    int totalQuantity = 0;

    for (var order in _summaryOrders) {
      for (var item in order.items) {
        final itemName = item.foodName ?? "Unknown Item";
        aggregatedItems[itemName] = (aggregatedItems[itemName] ?? 0) + item.quantity;
        totalQuantity += item.quantity;
      }
    }

    // Item lines
    aggregatedItems.forEach((name, qty) {
      sb.writeln("- $name - ${_formatQuantity(qty)}");
    });

    // Total line
    sb.writeln("Jumla: ${_formatQuantity(totalQuantity)}");

    return sb.toString();
  }
  // --- End Methods for Daily Order Summary ---

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
  }) {
    final theme = Theme.of(context);
    final bool canAccess = (requiresSuperAdmin && _isSuperAdmin) || !requiresSuperAdmin;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: canAccess ? onTap : () {
          if (requiresSuperAdmin && !_isSuperAdmin) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Access Denied: Super Administrator role required.')),
            );
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: canAccess ? 1.0 : 0.6,
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
                if (requiresSuperAdmin && !_isSuperAdmin)
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

  Widget _buildDailyOrderSummaryWidget(BuildContext context) {
    final theme = Theme.of(context);
    final isLightMode = theme.brightness == Brightness.light; // Check for light mode

    Map<String, int> aggregatedItems = {};
    int totalQuantity = 0;
    String companyNameDisplay = "N/A Company";

    if (_summaryOrders.isNotEmpty) {
      if (_summaryOrders.first.companyName != null && _summaryOrders.first.companyName!.isNotEmpty) {
        if (_summaryOrders.every((order) => order.companyName == _summaryOrders.first.companyName)) {
          companyNameDisplay = _summaryOrders.first.companyName!;
        } else {
          companyNameDisplay = "Multiple Companies";
        }
      } else if (_summaryOrders.map((o) => o.companyName).toSet().length > 1 && _summaryOrders.any((o)=> o.companyName != null && o.companyName!.isNotEmpty) ) {
        companyNameDisplay = "Multiple Companies";
      }

      for (var order in _summaryOrders) {
        for (var item in order.items) {
          final itemName = item.foodName ?? "Unknown Item";
          aggregatedItems[itemName] = (aggregatedItems[itemName] ?? 0) + item.quantity;
          totalQuantity += item.quantity;
        }
      }
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Daily Order Summary", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      if (_currentSummaryPeriodDisplay.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0),
                          child: Text(_currentSummaryPeriodDisplay, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 2,),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_all_outlined, color: Colors.blueAccent),
                  tooltip: "Copy Summary",
                  onPressed: () {
                    final summaryText = _buildSummaryTextForClipboard();
                    Clipboard.setData(ClipboardData(text: summaryText));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Summary copied to clipboard!')),
                    );
                  },
                ),
              ],
            ),
            const Divider(height: 20),
            if (_summaryOrders.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.hourglass_empty, size: 30, color: Colors.blueGrey),
                      const SizedBox(height: 8),
                      Text(
                        "No '${_summaryOrderStatusString.capitalizeFirst()}' orders for the current summary period.",
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      companyNameDisplay,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text("Floor: ", style: TextStyle(fontSize: 14)),
                  SizedBox(
                    width: 55,
                    height: 38,
                    child: TextField(
                      controller: _floorController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.text,
                      decoration: InputDecoration(
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          isDense: true,
                          hintText: "06",
                          hintStyle: TextStyle(color: Colors.grey.shade400)
                      ),
                      style: const TextStyle(fontSize: 14),
                      onChanged: (value) {
                        setState(() {
                          _editableFloorNumber = value.trim().isEmpty ? "06" : value.trim();
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: aggregatedItems.length,
                itemBuilder: (context, index) {
                  final entry = aggregatedItems.entries.elementAt(index);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(entry.key, style: theme.textTheme.bodyMedium)),
                        Text(_formatQuantity(entry.value), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  );
                },
              ),
              const Divider(height: 20, thickness: 0.5, indent: 10, endIndent: 10),
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      "Jumla ", // Changed from "Jumla: " to match UI style
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _formatQuantity(totalQuantity),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 15),
            Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text("Refresh Summary"),
                onPressed: _determinePeriodAndFetchData,
                style: ElevatedButton.styleFrom(
                  // **** MODIFICATION HERE for better visibility ****
                  backgroundColor: isLightMode
                      ? theme.colorScheme.primary // Use primary color in light mode
                      : theme.colorScheme.secondaryContainer, // Keep as is for dark mode
                  foregroundColor: isLightMode
                      ? theme.colorScheme.onPrimary // Text/icon color on primary
                      : theme.colorScheme.onSecondaryContainer, // Text/icon color on secondary container
                  // **** END MODIFICATION ****
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ),
          ],
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
              'Welcome, ${_isSuperAdmin ? "Super Administrator" : (_currentUserRole?.capitalizeFirst() ?? "Administrator")}!',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (_currentUserEmail != null)
              Padding(
                padding: const EdgeInsets.only(top: 2.0, bottom: 16.0),
                child: Text('Logged in as: $_currentUserEmail', style: theme.textTheme.bodySmall),
              ),
            _buildDailyOrderSummaryWidget(context),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 750 ? 3 : (MediaQuery.of(context).size.width > 500 ? 2 : 1),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: MediaQuery.of(context).size.width > 500 ? 1.1 : 1.4,
              children: [
                _buildDashboardCard(
                  context: context,
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'User Invitation',
                  subtitle: 'Invite or add new users to the system.',
                  onTap: () => _navigateTo(context, AdminInviteUserScreen.routeName, superAdminOnly: true),
                  requiresSuperAdmin: true,
                ),
                _buildDashboardCard(
                  context: context,
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'Permissions Mgt.',
                  subtitle: 'Grant/revoke permissions for other admins.',
                  onTap: () => _navigateTo(context, AdminPermissionsScreen.routeName, superAdminOnly: true),
                  requiresSuperAdmin: true,
                ),
                _buildDashboardCard(
                  context: context,
                  icon: Icons.manage_accounts_outlined,
                  title: 'Manage Users',
                  subtitle: 'Browse and manage all user accounts.',
                  onTap: () => _navigateTo(context, AdminManageUsersScreen.routeName, superAdminOnly: true),
                  requiresSuperAdmin: true,
                ),
                _buildDashboardCard(
                  context: context,
                  icon: Icons.business_center_outlined,
                  title: 'Manage Companies',
                  subtitle: 'Browse and manage company profiles.',
                  onTap: () => _navigateTo(context, AdminManageCompaniesScreen.routeName, superAdminOnly: true),
                  requiresSuperAdmin: true,
                ),
                _buildDashboardCard(
                  context: context,
                  icon: Icons.restaurant_menu_outlined,
                  title: 'Manage All Foods',
                  subtitle: 'Oversee all food items in the system.',
                  onTap: () => _navigateTo(context, AdminManageFoodsScreen.routeName, superAdminOnly: true),
                  requiresSuperAdmin: true,
                ),
                _buildDashboardCard(
                  context: context,
                  icon: Icons.receipt_long_outlined,
                  title: 'Manage All Orders',
                  subtitle: 'Monitor all system orders and statuses.',
                  onTap: () => _navigateTo(context, AdminManageOrdersScreen.routeName, superAdminOnly: true),
                  requiresSuperAdmin: true,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDashboardCard(
              context: context,
              icon: Icons.analytics_outlined,
              title: 'System Analytics',
              subtitle: 'View summaries of users, companies, sales.',
              onTap: () => _navigateTo(context, AdminAnalyticsScreen.routeName, superAdminOnly: false),
            ),
          ],
        ),
      ),
    );
  }
}
