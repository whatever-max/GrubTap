// lib/screens/admin/admin_permissions_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:grubtap/services/session_service.dart';
import 'package:grubtap/models/user_model.dart';
import 'package:grubtap/utils/string_extensions.dart'; // <<< CORRECT IMPORT
import 'package:flutter/foundation.dart';

// Model for UI representation of a permission setting
class PermissionSetting {
  final String permissionType;
  final String description;
  bool canView;
  bool canEdit;
  bool canDelete;
  bool canInvite; // For "add" capability in some contexts like companies/foods

  PermissionSetting({
    required this.permissionType,
    required this.description,
    this.canView = false,
    this.canEdit = false,
    this.canDelete = false,
    this.canInvite = false,
  });
}

class AdminPermissionsScreen extends StatefulWidget {
  static const String routeName = '/admin-permissions';
  const AdminPermissionsScreen({super.key});

  @override
  State<AdminPermissionsScreen> createState() => _AdminPermissionsScreenState();
}

class _AdminPermissionsScreenState extends State<AdminPermissionsScreen> {
  final supabase = Supabase.instance.client;
  List<UserModel> _otherAdmins = [];
  bool _isLoadingAdmins = true;
  String? _errorMessage;
  String? _superAdminId;

  UserModel? _selectedAdminForPermissions;
  Map<String, PermissionSetting> _currentPermissions = {};
  bool _isLoadingPermissions = false;
  bool _isSavingPermissions = false;

  final Map<String, String> _masterPermissionTypes = {
    'MANAGE_USERS': 'Manage Users (View, Edit, Delete Non-SA, Invite)',
    'MANAGE_COMPANIES': 'Manage Company Profiles (View, Edit, Delete, Add)',
    'MANAGE_FOODS_ALL': 'Manage All Food Items (View, Edit, Delete, Add)',
    'MANAGE_ORDERS_ALL': 'Manage All System Orders (View, Edit Status)',
    // 'VIEW_ANALYTICS': 'View System Analytics & Summaries',
  };

  @override
  void initState() {
    super.initState();
    final currentUser = SessionService.getCurrentUser();
    if (currentUser?.email == 'fiqraadmin@gmail.com') {
      _superAdminId = currentUser!.id;
      _fetchOtherAdmins();
    } else {
      setState(() {
        _isLoadingAdmins = false;
        _errorMessage = "Access Denied: Only Super Administrator can manage permissions.";
      });
    }
  }

  Future<void> _fetchOtherAdmins() async {
    if (!mounted || _superAdminId == null) return;
    setState(() {
      _isLoadingAdmins = true;
      _errorMessage = null;
      _otherAdmins = [];
      _selectedAdminForPermissions = null;
      _currentPermissions = {};
    });

    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('role', 'admin')
          .neq('id', _superAdminId!)
          .order('username', ascending: true);

      if (!mounted) return;
      _otherAdmins = response.map((data) => UserModel.fromMap(data)).toList();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "Error fetching admins: ${e.toString()}");
        debugPrint("[AdminPermsScreen] Error fetching admins: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoadingAdmins = false);
    }
  }

  Future<void> _loadPermissionsForAdmin(UserModel admin) async {
    if (!mounted) return;
    setState(() {
      _selectedAdminForPermissions = admin;
      _isLoadingPermissions = true;
      _currentPermissions = {};
      _errorMessage = null;
    });

    try {
      final existingPermsResponse = await supabase
          .from('admin_permissions')
          .select()
          .eq('admin_user_id', admin.id);

      if (!mounted) return;

      Map<String, PermissionSetting> loadedPermissions = {};
      _masterPermissionTypes.forEach((typeKey, typeDescription) {
        loadedPermissions[typeKey] = PermissionSetting(
          permissionType: typeKey,
          description: typeDescription,
        );
      });

      for (var row in existingPermsResponse) {
        final type = row['permission_type'] as String;
        if (loadedPermissions.containsKey(type)) {
          loadedPermissions[type]!.canView = row['can_view'] ?? false;
          loadedPermissions[type]!.canEdit = row['can_edit'] ?? false;
          loadedPermissions[type]!.canDelete = row['can_delete'] ?? false;
          loadedPermissions[type]!.canInvite = row['can_invite'] ?? false;
        }
      }
      _currentPermissions = loadedPermissions;
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = "Error loading permissions for ${admin.username}: ${e.toString()}");
        debugPrint("[AdminPermsScreen] Error loading permissions for ${admin.username}: $e");
      }
    } finally {
      if (mounted) setState(() => _isLoadingPermissions = false);
    }
  }

  Future<void> _savePermissions() async {
    if (_selectedAdminForPermissions == null || _superAdminId == null || _isSavingPermissions) return;

    setState(() => _isSavingPermissions = true);

    List<Map<String, dynamic>> upsertData = [];
    _currentPermissions.forEach((type, setting) {
      upsertData.add({
        'admin_user_id': _selectedAdminForPermissions!.id,
        'granted_by_super_admin_id': _superAdminId!,
        'permission_type': type,
        'can_view': setting.canView,
        'can_edit': setting.canEdit,
        'can_delete': setting.canDelete,
        'can_invite': setting.canInvite,
        'updated_at': DateTime.now().toIso8601String(),
        // 'target_id' is null or not used for these general permissions
      });
    });

    try {
      // Assuming your unique constraint for general permissions is on (admin_user_id, permission_type)
      // If your constraint INCLUDES target_id, and target_id is NULL for these,
      // you might need to adjust the onConflict or ensure your DB handles NULLs in unique constraints as expected (Postgres treats NULLs as distinct).
      // A common approach for general permissions is to have a constraint only on (admin_user_id, permission_type).
      await supabase.from('admin_permissions').upsert(
        upsertData,
        onConflict: 'admin_user_id, permission_type',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Permissions saved for ${_selectedAdminForPermissions!.username}.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving permissions: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error),
        );
        debugPrint("[AdminPermsScreen] Error saving permissions: $e");
      }
    } finally {
      if (mounted) setState(() => _isSavingPermissions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (SessionService.getCurrentUser()?.email != 'fiqraadmin@gmail.com') {
      return Scaffold(
        appBar: AppBar(title: const Text('Permissions Management')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 60, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text('Access Denied', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.error)),
                const SizedBox(height: 8),
                const Text('Only the Super Administrator can manage user permissions.', textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    Widget leftPanelContent;
    if (_isLoadingAdmins) {
      leftPanelContent = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null && _otherAdmins.isEmpty) {
      leftPanelContent = Center(child: Padding(padding: const EdgeInsets.all(8.0), child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center)));
    } else if (_otherAdmins.isEmpty) {
      leftPanelContent = const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text('No other admin accounts found.', textAlign: TextAlign.center)));
    } else {
      leftPanelContent = ListView.builder(
        itemCount: _otherAdmins.length,
        itemBuilder: (context, index) {
          final admin = _otherAdmins[index];
          return ListTile(
            leading: CircleAvatar(child: Text(admin.username.isNotEmpty ? admin.username[0].toUpperCase() : 'A')),
            title: Text(admin.username, style: TextStyle(fontWeight: _selectedAdminForPermissions?.id == admin.id ? FontWeight.bold : FontWeight.normal)),
            subtitle: Text(admin.email),
            selected: _selectedAdminForPermissions?.id == admin.id,
            selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
            onTap: () => _loadPermissionsForAdmin(admin),
          );
        },
      );
    }

    Widget rightPanelContent;
    if (_selectedAdminForPermissions == null) {
      rightPanelContent = const Center(child: Text('Select an admin to manage permissions.'));
    } else if (_isLoadingPermissions) {
      rightPanelContent = const Center(child: CircularProgressIndicator());
    } else if (_errorMessage != null && _currentPermissions.isEmpty && _selectedAdminForPermissions != null) { // Show error only if it's for the selected admin's permissions
      rightPanelContent = Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error), textAlign: TextAlign.center)));
    } else {
      rightPanelContent = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Permissions for: ${_selectedAdminForPermissions!.username.capitalizeFirst()}', // Uses extension
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: ListView(
              children: _currentPermissions.entries.map((entry) {
                final permissionKey = entry.key;
                final setting = entry.value;
                bool showInviteFlag = permissionKey == 'MANAGE_USERS' || permissionKey == 'MANAGE_COMPANIES' || permissionKey == 'MANAGE_FOODS_ALL';

                return Card(
                  elevation: 1.5,
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(setting.description, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(child: CheckboxListTile(title: const Text('View'), value: setting.canView, dense: true, controlAffinity: ListTileControlAffinity.leading, onChanged: _isSavingPermissions ? null : (val) => setState(() => setting.canView = val ?? false))),
                            Flexible(child: CheckboxListTile(title: const Text('Edit'), value: setting.canEdit, dense: true, controlAffinity: ListTileControlAffinity.leading, onChanged: _isSavingPermissions ? null : (val) => setState(() => setting.canEdit = val ?? false))),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(child: CheckboxListTile(title: const Text('Delete'), value: setting.canDelete, dense: true, controlAffinity: ListTileControlAffinity.leading, onChanged: _isSavingPermissions ? null : (val) => setState(() => setting.canDelete = val ?? false))),
                            if (showInviteFlag)
                              Flexible(child: CheckboxListTile(title: Text(permissionKey == 'MANAGE_USERS' ? 'Invite' : 'Add New'), value: setting.canInvite, dense: true, controlAffinity: ListTileControlAffinity.leading, onChanged: _isSavingPermissions ? null : (val) => setState(() => setting.canInvite = val ?? false))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: _isSavingPermissions ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_alt_outlined),
            label: Text(_isSavingPermissions ? 'Saving...' : 'Save Permissions'),
            onPressed: (_isSavingPermissions || _selectedAdminForPermissions == null) ? null : _savePermissions,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Permissions Control')),
      body: Row(
        children: [
          Expanded(flex: 2, child: Container(decoration: BoxDecoration(border: Border(right: BorderSide(color: theme.dividerColor, width: 0.5))), child: leftPanelContent)),
          Expanded(flex: 3, child: Padding(padding: const EdgeInsets.all(16.0), child: rightPanelContent)),
        ],
      ),
    );
  }
}
