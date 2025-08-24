// lib/screens/admin/admin_analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:grubtap/services/session_service.dart';
import 'package:grubtap/models/user_model.dart';
import 'package:grubtap/models/company_model.dart';
import 'package:grubtap/models/food_item_model.dart';
import 'package:grubtap/models/order_model.dart'; // Using your modified OrderModel
import 'package:grubtap/utils/string_extensions.dart';
import 'package:collection/collection.dart'; // For groupBy, sumBy etc.
// import 'package:fl_chart/fl_chart.dart'; // Uncomment if using fl_chart
// import 'package:intl/intl.dart';      // Uncomment if using DateFormat for charts

// --- Models for Calculated Analytics Data ---
class CalculatedSalesSummary {
  final double totalSales;
  final int totalOrders;
  final double averageOrderValue;
  final int totalFoodItemsSoldCount;

  CalculatedSalesSummary({
    required this.totalSales,
    required this.totalOrders,
    required this.averageOrderValue,
    required this.totalFoodItemsSoldCount,
  });

  factory CalculatedSalesSummary.empty() => CalculatedSalesSummary(
      totalSales: 0,
      totalOrders: 0,
      averageOrderValue: 0,
      totalFoodItemsSoldCount: 0);
}

class CalculatedUserStats {
  final int totalUsers;
  final int newUsersToday;
  final int totalCompanyAccounts;
  final int totalAdminUsers;

  CalculatedUserStats({
    required this.totalUsers,
    required this.newUsersToday,
    required this.totalCompanyAccounts,
    required this.totalAdminUsers,
  });

  factory CalculatedUserStats.empty() => CalculatedUserStats(
      totalUsers: 0,
      newUsersToday: 0,
      totalCompanyAccounts: 0,
      totalAdminUsers: 0);
}

class CalculatedContentStats {
  final int totalFoodItems;

  CalculatedContentStats({
    required this.totalFoodItems,
  });
  factory CalculatedContentStats.empty() =>
      CalculatedContentStats(totalFoodItems: 0);
}

class TimeSeriesSalesDataPoint {
  final DateTime date;
  final double salesAmount;
  final int orderCount;
  TimeSeriesSalesDataPoint(this.date, this.salesAmount, this.orderCount);
}

class AdminAnalyticsScreen extends StatefulWidget {
  static const String routeName = '/admin-analytics';
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _errorMessage;

  List<UserModel> _allUsers = [];
  List<CompanyModel> _allCompanies = [];
  List<FoodItemModel> _allFoodItems = [];
  List<OrderModel> _allOrders = [];

  CalculatedSalesSummary _salesSummary = CalculatedSalesSummary.empty();
  CalculatedUserStats _userStats = CalculatedUserStats.empty();
  CalculatedContentStats _contentStats = CalculatedContentStats.empty();
  List<TimeSeriesSalesDataPoint> _dailySalesData = [];

  // Use ID for super admin check for robustness
  bool get _isSuperAdmin => SessionService.getCurrentUser()?.id == 'ddbf93e1-f6bd-4295-a3a6-6348fe6fdf96';
  bool _canViewAnalytics = false;

  @override
  void initState() {
    super.initState();
    _loadInitialDataAndCalculateAnalytics();
  }

  Future<void> _loadInitialDataAndCalculateAnalytics() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    await _fetchAnalyticsPermissions();

    if (_isSuperAdmin || _canViewAnalytics) {
      try {
        final results = await Future.wait([
          supabase.from('users').select(),
          supabase.from('companies').select('*, users (id, username)'),
          supabase.from('foods').select('*, companies (name)'),
          supabase.from('orders').select(''' 
              id, user_id, company_id, order_time, status, 
              users (email, username, first_name, last_name, created_at), 
              companies (name),
              order_items ( quantity, item_price, foods ( id, name, price ) )
            '''), // <<< CORRECTED: Removed direct quantity, total_price from orders SELECT
        ]);

        if (!mounted) return;

        _allUsers = (results[0] as List)
            .map((data) => UserModel.fromMap(data as Map<String, dynamic>))
            .toList();
        _allCompanies = (results[1] as List)
            .map((data) => CompanyModel.fromMap(data as Map<String, dynamic>))
            .toList();
        _allFoodItems = (results[2] as List)
            .map((data) => FoodItemModel.fromMap(data as Map<String, dynamic>))
            .toList();
        _allOrders = (results[3] as List)
            .map((data) => OrderModel.fromMap(data as Map<String, dynamic>))
            .toList(); // OrderModel.fromMap now handles summing quantity/price from items if needed

        _calculateAllAnalytics();
      } catch (e, s) {
        if (mounted) {
          debugPrint("[AnalyticsScreen] Error fetching data: $e\nStack: $s");
          setState(
                  () => _errorMessage = "Error loading data for analytics: ${e.toString()}");
        }
      }
    } else {
      if (mounted) {
        setState(() => _errorMessage = "You do not have permission to view analytics.");
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchAnalyticsPermissions() async {
    if (_isSuperAdmin) {
      if (mounted) setState(() => _canViewAnalytics = true);
      return;
    }
    final currentUserId = SessionService.getCurrentUser()?.id;
    if (currentUserId == null) {
      if (mounted) setState(() => _canViewAnalytics = false);
      return;
    }
    try {
      final response = await supabase
          .from('admin_permissions')
          .select('can_view')
          .eq('admin_user_id', currentUserId)
          .eq('permission_type', 'VIEW_ANALYTICS')
          .maybeSingle();
      if (mounted) {
        setState(() => _canViewAnalytics = response?['can_view'] ?? false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "Error loading analytics permissions.");
      }
      debugPrint("[AnalyticsScreen] Perms Error: $e");
    }
  }

  void _calculateAllAnalytics() {
    if (!mounted) return;

    double totalSalesCalc = 0;
    int totalFoodItemsSoldCountCalc = 0;

    final billableOrders = _allOrders
        .where((o) =>
    o.status == AdminOrderStatus.completed ||
        o.status == AdminOrderStatus.readyForPickup)
        .toList();

    for (var order in billableOrders) {
      // REINSTATED NULL CHECKS (as per your initial clean version logic)
      // because OrderModel.totalPrice and OrderModel.quantity are still nullable (int?/double?)
      totalSalesCalc += order.totalPrice ?? 0.0;
      totalFoodItemsSoldCountCalc += order.quantity ?? 0;
    }

    int totalValidOrderRecords = billableOrders.length;
    double avgOrderValueCalc =
    totalValidOrderRecords > 0 ? totalSalesCalc / totalValidOrderRecords : 0;

    _salesSummary = CalculatedSalesSummary(
      totalSales: totalSalesCalc,
      totalOrders: totalValidOrderRecords,
      averageOrderValue: avgOrderValueCalc,
      totalFoodItemsSoldCount: totalFoodItemsSoldCountCalc,
    );

    int totalUsersCount = _allUsers.length;
    int newUsersTodayCount = 0;

    int totalAdminUsersCountCalc =
        _allUsers.where((u) => u.role == 'admin').length;

    _userStats = CalculatedUserStats(
      totalUsers: totalUsersCount,
      newUsersToday: newUsersTodayCount,
      totalCompanyAccounts: _allCompanies.length,
      totalAdminUsers: totalAdminUsersCountCalc,
    );

    _contentStats = CalculatedContentStats(
      totalFoodItems: _allFoodItems.length,
    );

    Map<DateTime, double> salesByDateAgg = {};
    Map<DateTime, int> ordersByDateAgg = {};
    DateTime todayStartForTrend = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    DateTime sevenDaysAgoStart = todayStartForTrend.subtract(const Duration(days: 6));

    for (var order in billableOrders) {
      DateTime orderDateOnly =
      DateTime(order.orderTime.year, order.orderTime.month, order.orderTime.day);
      if (!orderDateOnly.isBefore(sevenDaysAgoStart)) {
        // REINSTATED NULL CHECKS (as per your initial clean version logic)
        final currentOrderPrice = order.totalPrice ?? 0.0;
        salesByDateAgg.update(
            orderDateOnly, (existingSales) => existingSales + currentOrderPrice,
            ifAbsent: () => currentOrderPrice);

        ordersByDateAgg.update(orderDateOnly, (existingCount) => existingCount + 1,
            ifAbsent: () => 1);
      }
    }
    _dailySalesData.clear();
    for (int i = 0; i < 7; i++) {
      DateTime date = todayStartForTrend.subtract(Duration(days: 6 - i));
      _dailySalesData.add(TimeSeriesSalesDataPoint(
          date, salesByDateAgg[date] ?? 0.0, ordersByDateAgg[date] ?? 0));
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_isSuperAdmin && !_canViewAnalytics && !_isLoading) {
      return Scaffold(
          appBar: AppBar(title: const Text('Analytics')),
          body: Center(
              child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_errorMessage ?? 'Access Denied.',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(color: theme.colorScheme.error),
                      textAlign: TextAlign.center))));
    }

    return Scaffold(
        appBar: AppBar(title: const Text('Dashboard & Analytics'), actions: [
          IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Analytics',
              onPressed: _isLoading
                  ? null
                  : _loadInitialDataAndCalculateAnalytics),
        ]),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? Center(
            child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(_errorMessage!,
                    style: TextStyle(
                        color: theme.colorScheme.error, fontSize: 16),
                    textAlign: TextAlign.center)))
            : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Overview",
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.spaceAround,
                      children: [
                        _buildMetricCard(
                            context,
                            "Total Sales",
                            "\$${_salesSummary.totalSales.toStringAsFixed(2)}",
                            Icons.monetization_on_outlined,
                            Colors.green),
                        _buildMetricCard(
                            context,
                            "Order Records",
                            _salesSummary.totalOrders.toString(),
                            Icons.receipt_long_outlined,
                            Colors.blue),
                        _buildMetricCard(
                            context,
                            "Avg. Order Value",
                            "\$${_salesSummary.averageOrderValue.toStringAsFixed(2)}",
                            Icons.price_check_outlined,
                            Colors.orange),
                        _buildMetricCard(
                            context,
                            "Total Items Sold",
                            _salesSummary.totalFoodItemsSoldCount
                                .toString(),
                            Icons.fastfood_outlined,
                            Colors.teal),
                        _buildMetricCard(
                            context,
                            "Registered Users",
                            _userStats.totalUsers.toString(),
                            Icons.people_alt_outlined,
                            Colors.purple),
                        _buildMetricCard(
                            context,
                            "Admin Accounts",
                            _userStats.totalAdminUsers.toString(),
                            Icons.admin_panel_settings_outlined,
                            Colors.redAccent),
                        _buildMetricCard(
                            context,
                            "Listed Companies",
                            _userStats.totalCompanyAccounts.toString(),
                            Icons.business_outlined,
                            Colors.brown),
                        _buildMetricCard(
                            context,
                            "Listed Food Items",
                            _contentStats.totalFoodItems.toString(),
                            Icons.restaurant_menu_outlined,
                            Colors.indigo),
                      ]),
                  const SizedBox(height: 24),
                  Text(
                      "Sales Trend (Last 7 Days - Based on Order Records)",
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    height: 300,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 16.0),
                    decoration: BoxDecoration(
                        border: Border.all(
                            color: theme.dividerColor.withOpacity(0.5)),
                        borderRadius: BorderRadius.circular(12),
                        color: theme.cardColor.withAlpha(30)),
                    child: _dailySalesData.isNotEmpty
                        ? _buildSalesLineChartWidgetPlaceholder(
                        context, _dailySalesData)
                        : const Center(
                        child: Text(
                            "Sales data processing or not available.")),
                  ),
                ])));
  }

  Widget _buildMetricCard(BuildContext context, String title, String value,
      IconData icon, Color iconColor) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: MediaQuery.of(context).size.width / 2 - 24,
        constraints: const BoxConstraints(minHeight: 120),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32, color: iconColor),
            const SizedBox(height: 12),
            Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(color: theme.textTheme.bodySmall?.color)),
            const SizedBox(height: 4),
            Text(value,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: iconColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesLineChartWidgetPlaceholder(
      BuildContext context, List<TimeSeriesSalesDataPoint> data) {
    if (data.isEmpty) return const Center(child: Text("No sales data."));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.insert_chart_outlined_rounded,
              size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text("Chart Data Ready",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
              "Integrate a charting library (e.g., fl_chart) to visualize the ${data.length} daily sales data points.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600])),
        ]),
      ),
    );
  }
}
