// lib/screens/admin/management/admin_manage_orders_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:grubtap/models/order_model.dart';
import 'package:grubtap/models/company_model.dart'; // For company filter
import 'package:grubtap/services/session_service.dart';
import 'package:grubtap/utils/string_extensions.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart'; // for describeEnum

class AdminManageOrdersScreen extends StatefulWidget {
  static const String routeName = '/admin-manage-orders';
  const AdminManageOrdersScreen({super.key});

  @override
  State<AdminManageOrdersScreen> createState() => _AdminManageOrdersScreenState();
}

class _AdminManageOrdersScreenState extends State<AdminManageOrdersScreen> {
  final supabase = Supabase.instance.client;
  List<OrderModel> _orders = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _searchTerm;

  // Filters
  AdminOrderStatus? _selectedStatusFilter;
  CompanyModel? _selectedCompanyFilter;
  DateTimeRange? _selectedDateRangeFilter;

  List<CompanyModel> _availableCompanies = []; // For company filter dropdown

  // Use ID for super admin check for robustness
  bool get _isSuperAdmin => SessionService.getCurrentUser()?.id == 'ddbf93e1-f6bd-4295-a3a6-6348fe6fdf96';

  bool _canViewAllOrders = false;
  bool _canEditAllOrdersStatus = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    await _fetchAdminOrderPermissions();
    if (_isSuperAdmin || _canViewAllOrders) {
      await _fetchAvailableCompaniesForDropdown();
      await _fetchOrders();
    } else {
      if(mounted) {
        setState(() {
          _orders = [];
          _availableCompanies = [];
          _errorMessage = "You do not have permission to view orders.";
        });
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchAdminOrderPermissions() async {
    if (_isSuperAdmin) {
      _canViewAllOrders = true;
      _canEditAllOrdersStatus = true;
      return;
    }
    final currentUserId = SessionService.getCurrentUser()?.id;
    if (currentUserId == null) {
      _canViewAllOrders = false; _canEditAllOrdersStatus = false; return;
    }
    try {
      final response = await supabase
          .from('admin_permissions')
          .select('can_view, can_edit')
          .eq('admin_user_id', currentUserId)
          .eq('permission_type', 'MANAGE_ORDERS_ALL')
          .maybeSingle();

      if (mounted) {
        if (response != null) {
          _canViewAllOrders = response['can_view'] ?? false;
          _canEditAllOrdersStatus = response['can_edit'] ?? false;
        } else {
          _canViewAllOrders = false; _canEditAllOrdersStatus = false;
        }
      }
    } catch (e) {
      debugPrint("[ManageOrdersScreen] Error fetching order permissions: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Error loading your order management permissions.";
          _canViewAllOrders = false; _canEditAllOrdersStatus = false;
        });
      }
    }
  }

  Future<void> _fetchAvailableCompaniesForDropdown() async {
    try {
      final response = await supabase.from('companies').select('id, name').order('name', ascending: true);
      if (!mounted) return;
      _availableCompanies = response.map((data) => CompanyModel.fromMap(data)).toList();
    } catch (e) {
      debugPrint("[ManageOrdersScreen] Error fetching companies for filter: $e");
      if(mounted) {
        setState(() {
          _availableCompanies = [];
          _errorMessage = (_errorMessage ?? "") + "\nCould not load companies for filter.";
        });
      }
    }
  }

  Future<void> _fetchOrders() async {
    if (!(_isSuperAdmin || _canViewAllOrders)) {
      if (mounted) {
        setState(() {
          _orders = [];
          _errorMessage = "Permission denied to fetch orders.";
        });
      }
      return;
    }

    try {
      var queryBuilder = supabase.from('orders').select('''
          id, 
          user_id, 
          company_id, 
          order_time, 
          status,
          users ( email, username, first_name, last_name ), 
          companies ( name ),
          order_items ( 
            quantity, 
            item_price, 
            foods ( id, name, price ) 
          )
        '''); // Removed quantity, total_price from direct orders select as they are not in schema

      if (_searchTerm != null && _searchTerm!.isNotEmpty) {
        final st = '%${_searchTerm!.trim()}%';
        queryBuilder = queryBuilder.or(
            'id::text.ilike.$st,'
                'users.email.ilike.$st,users.username.ilike.$st,users.first_name.ilike.$st,users.last_name.ilike.$st,'
                'companies.name.ilike.$st'
        );
      }

      if (_selectedStatusFilter != null) {
        queryBuilder = queryBuilder.eq('status', describeEnum(_selectedStatusFilter!));
      }
      if (_selectedCompanyFilter != null) {
        queryBuilder = queryBuilder.eq('company_id', _selectedCompanyFilter!.id);
      }
      if (_selectedDateRangeFilter != null) {
        queryBuilder = queryBuilder
            .gte('order_time', _selectedDateRangeFilter!.start.toIso8601String())
            .lte('order_time', _selectedDateRangeFilter!.end.toIso8601String());
      }

      final orderedQueryBuilder = queryBuilder.order('order_time', ascending: false);
      final response = await orderedQueryBuilder;

      if (!mounted) return;
      _orders = response.map((data) => OrderModel.fromMap(data)).toList();

      if (_orders.isEmpty && (_searchTerm?.isNotEmpty == true || _selectedStatusFilter != null || _selectedCompanyFilter != null || _selectedDateRangeFilter != null)) {
        if(mounted) setState(() => _errorMessage = 'No orders match your criteria.');
      } else if (mounted) {
        setState(() => _errorMessage = null);
      }
    } catch (e) {
      if (mounted) {
        debugPrint("[ManageOrdersScreen] Error fetching orders: $e");
        setState(() {
          _errorMessage = "Error fetching orders: ${e.toString()}";
          _orders = [];
        });
      }
    }
  }

  Future<void> _showUpdateStatusDialog(OrderModel order) async {
    if (!(_isSuperAdmin || _canEditAllOrdersStatus)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You do not have permission to update order status.')));
      return;
    }

    AdminOrderStatus initialStatusForDialog = order.status;

    final AdminOrderStatus? newStatus = await showDialog<AdminOrderStatus>(
      context: context,
      builder: (dialogContext) {
        AdminOrderStatus tempStatusInDialog = initialStatusForDialog;
        return StatefulBuilder(
            builder: (stfContext, stfSetStateDialog) {
              return AlertDialog(
                title: Text('Update Status for Order #${order.id.substring(0, 8)}'),
                content: DropdownButton<AdminOrderStatus>(
                  value: tempStatusInDialog,
                  isExpanded: true,
                  items: AdminOrderStatus.values
                      .where((s) => s != AdminOrderStatus.unknown)
                      .map((AdminOrderStatus status) {
                    return DropdownMenuItem<AdminOrderStatus>(
                      value: status,
                      child: Text(describeEnum(status).capitalizeFirst()),
                    );
                  }).toList(),
                  onChanged: (AdminOrderStatus? newValue) {
                    if (newValue != null) {
                      stfSetStateDialog(() {
                        tempStatusInDialog = newValue;
                      });
                    }
                  },
                ),
                actions: <Widget>[
                  TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                  TextButton(
                    child: const Text('Update'),
                    onPressed: () => Navigator.of(dialogContext).pop(tempStatusInDialog),
                  ),
                ],
              );
            }
        );
      },
    );

    if (newStatus != null && newStatus != order.status && mounted) {
      setState(() => _isLoading = true);
      try {
        await supabase
            .from('orders')
            .update({'status': describeEnum(newStatus)})
            .eq('id', order.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Order status updated to ${describeEnum(newStatus).capitalizeFirst()}.'), backgroundColor: Colors.green),
          );
          _fetchOrders();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating status: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRangeFilter ?? DateTimeRange(start: DateTime.now().subtract(const Duration(days: 7)), end: DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDateRangeFilter) {
      setState(() {
        _selectedDateRangeFilter = DateTimeRange(
            start: DateTime(picked.start.year, picked.start.month, picked.start.day),
            end: DateTime(picked.end.year, picked.end.month, picked.end.day, 23, 59, 59, 999)
        );
        _fetchOrders();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final DateFormat dateTimeFormat = DateFormat('MMM dd, yyyy hh:mm a');

    if (!_isSuperAdmin && !_canViewAllOrders && !_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Orders')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage ?? 'Access Denied: You do not have permission to view orders.',
              style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage All Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Orders',
            onPressed: _isLoading ? null : () => _loadInitialData(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (value) {
                    if (mounted) {
                      setState(() => _searchTerm = value);
                      Future.delayed(const Duration(milliseconds: 400), () {
                        if (mounted && _searchTerm == value) _fetchOrders();
                      });
                    }
                  },
                  decoration: InputDecoration(
                      hintText: 'Search Order ID, User, Company...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<AdminOrderStatus?>(
                        value: _selectedStatusFilter,
                        hint: const Text('All Statuses'),
                        decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            filled: true),
                        items: [
                          const DropdownMenuItem<AdminOrderStatus?>(value: null, child: Text("All Statuses")),
                          ...AdminOrderStatus.values.where((s) => s != AdminOrderStatus.unknown).map((AdminOrderStatus status) {
                            return DropdownMenuItem<AdminOrderStatus?>(value: status, child: Text(describeEnum(status).capitalizeFirst()));
                          })
                        ],
                        onChanged: (AdminOrderStatus? newValue) {
                          setState(() {
                            _selectedStatusFilter = newValue;
                            _fetchOrders();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<CompanyModel?>(
                        value: _selectedCompanyFilter,
                        hint: const Text('All Companies'),
                        decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            filled: true),
                        items: [
                          const DropdownMenuItem<CompanyModel?>(value: null, child: Text("All Companies")),
                          ..._availableCompanies.map((CompanyModel company) {
                            return DropdownMenuItem<CompanyModel?>(value: company, child: Text(company.name, overflow: TextOverflow.ellipsis));
                          })
                        ],
                        onChanged: (CompanyModel? newValue) {
                          setState(() {
                            _selectedCompanyFilter = newValue;
                            _fetchOrders();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.date_range),
                      tooltip: 'Filter by Date Range',
                      onPressed: () => _selectDateRange(context),
                    ),
                    if (_selectedDateRangeFilter != null)
                      IconButton(
                        icon: Icon(Icons.clear, color: theme.colorScheme.error),
                        tooltip: 'Clear Date Filter',
                        onPressed: () {
                          setState(() {
                            _selectedDateRangeFilter = null;
                            _fetchOrders();
                          });
                        },
                      ),
                  ],
                ),
                if (_selectedDateRangeFilter != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Date: ${DateFormat.yMd().format(_selectedDateRangeFilter!.start)} - ${DateFormat.yMd().format(_selectedDateRangeFilter!.end)}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null && _orders.isEmpty
                ? Center(
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 16), textAlign: TextAlign.center)))
                : _orders.isEmpty
                ? Center(
                child: Text(
                    _searchTerm?.isNotEmpty == true || _selectedStatusFilter != null || _selectedCompanyFilter != null || _selectedDateRangeFilter != null
                        ? 'No orders match your criteria.'
                        : 'No orders found.'
                )
            )
                : ListView.builder(
              itemCount: _orders.length,
              itemBuilder: (context, index) {
                final order = _orders[index];
                final canEditThisOrder = _isSuperAdmin || _canEditAllOrdersStatus;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                'Order ID: #${order.id.substring(0, 8)}...',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            Chip(
                              label: Text(describeEnum(order.status).capitalizeFirst(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              backgroundColor: _getStatusColor(order.status, theme).withOpacity(0.2),
                              labelStyle: TextStyle(color: _getStatusColor(order.status, theme)),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const Divider(height: 16, thickness: 0.5),

                        // Use foodNameDisplay from OrderModel
                        if (order.foodNameDisplay != null) // <<< CORRECTED
                          Text('Items: ${order.foodNameDisplay}${order.quantity > 0 ? " (Qty: ${order.quantity})" : ""}', // <<< CORRECTED (also changed quantity to non-nullable based on OrderModel)
                              style: theme.textTheme.bodyMedium),
                        // order.totalPrice is now non-nullable based on OrderModel
                        Text('Total: TSh ${order.totalPrice.toStringAsFixed(0)}/=',
                            style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),


                        const SizedBox(height: 6),
                        Text('Customer: ${order.userName ?? order.userEmail ?? "N/A"}', style: theme.textTheme.bodySmall),
                        if (order.companyName != null) Text('Company: ${order.companyName}', style: theme.textTheme.bodySmall),
                        Text('Ordered: ${dateTimeFormat.format(order.orderTime.toLocal())}', style: theme.textTheme.bodySmall),
                        const SizedBox(height: 8),

                        if (canEditThisOrder)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              icon: const Icon(Icons.edit_note, size: 18),
                              label: const Text('Update Status'),
                              onPressed: () => _showUpdateStatusDialog(order),
                              style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  textStyle: const TextStyle(fontSize: 13)
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(AdminOrderStatus status, ThemeData theme) {
    switch (status) {
      case AdminOrderStatus.pending:
        return Colors.orange.shade700;
      case AdminOrderStatus.confirmed:
        return Colors.blue.shade700;
      case AdminOrderStatus.preparing:
        return Colors.deepPurple.shade400;
      case AdminOrderStatus.readyForPickup:
        return Colors.teal.shade600;
      case AdminOrderStatus.completed:
        return Colors.green.shade700;
      case AdminOrderStatus.cancelled:
        return theme.colorScheme.error;
      case AdminOrderStatus.unknown:
      default:
        return theme.textTheme.bodySmall?.color ?? Colors.grey.shade600;
    }
  }
}

