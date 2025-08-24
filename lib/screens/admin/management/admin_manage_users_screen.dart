// lib/screens/admin/management/admin_manage_users_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:grubtap/models/user_model.dart';
import 'package:grubtap/services/session_service.dart';
import 'package:grubtap/screens/admin/admin_invite_user_screen.dart';
// import 'package:email_validator/email_validator.dart'; // Not strictly needed if email isn't directly editable in the form
import 'package:flutter/foundation.dart';
import 'package:grubtap/utils/string_extensions.dart'; // <<<<<< IMPORT YOUR SHARED EXTENSION

// Model to hold an admin's specific permissions for this screen's context
class UserManagementPermissions {
  final bool canView;
  final bool canEdit;
  final bool canDelete;
  final bool canGoToInviteScreen;

  UserManagementPermissions({
    this.canView = false,
    this.canEdit = false,
    this.canDelete = false,
    this.canGoToInviteScreen = false,
  });
}

class AdminManageUsersScreen extends StatefulWidget {
  static const String routeName = '/admin-manage-users';
  const AdminManageUsersScreen({super.key});

  @override
  State<AdminManageUsersScreen> createState() => _AdminManageUsersScreenState();
}

class _AdminManageUsersScreenState extends State<AdminManageUsersScreen> {
  final supabase = Supabase.instance.client;
  List<UserModel> _users = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _searchTerm;

  final _currentUserEmail = SessionService.getCurrentUser()?.email;
  bool get _isSuperAdmin => _currentUserEmail == 'fiqraadmin@gmail.com';
  UserManagementPermissions _adminPermissions = UserManagementPermissions();

  final _editFormKey = GlobalKey<FormState>();
  final _editUsernameController = TextEditingController();
  final _editFirstNameController = TextEditingController();
  final _editLastNameController = TextEditingController();
  final _editEmailController = TextEditingController();
  final _editPhoneController = TextEditingController();
  final _editRoleController = ValueNotifier<String>('user');
  final List<String> _assignableRoles = ['user', 'company', 'admin'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _editUsernameController.dispose();
    _editFirstNameController.dispose();
    _editLastNameController.dispose();
    _editEmailController.dispose();
    _editPhoneController.dispose();
    _editRoleController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (!_isSuperAdmin) {
      await _fetchAdminPermissions();
    } else {
      _adminPermissions = UserManagementPermissions(canView: true, canEdit: true, canDelete: true, canGoToInviteScreen: true);
    }
    await _fetchUsers(searchTerm: _searchTerm);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchAdminPermissions() async {
    if (_isSuperAdmin || SessionService.getCurrentUser() == null) {
      _adminPermissions = UserManagementPermissions(canView: false);
      return;
    }
    try {
      final response = await supabase
          .from('admin_permissions')
          .select('can_view, can_edit, can_delete, can_invite')
          .eq('admin_user_id', SessionService.getCurrentUser()!.id)
          .eq('permission_type', 'MANAGE_USERS')
          .maybeSingle();

      if (response != null && mounted) {
        _adminPermissions = UserManagementPermissions(
          canView: response['can_view'] ?? false,
          canEdit: response['can_edit'] ?? false,
          canDelete: response['can_delete'] ?? false,
          canGoToInviteScreen: response['can_invite'] ?? false,
        );
      } else {
        _adminPermissions = UserManagementPermissions();
      }
    } catch (e) {
      debugPrint("[ManageUsersScreen] Error fetching admin permissions: $e");
      _adminPermissions = UserManagementPermissions();
      if (mounted) setState(() => _errorMessage = "Error loading your permissions.");
    }
  }

  Future<void> _fetchUsers({String? searchTerm}) async {
    if (!_isSuperAdmin && !_adminPermissions.canView) {
      if (mounted) {
        setState(() {
          _users = [];
          _errorMessage = "You do not have permission to view users.";
        });
      }
      return;
    }

    try {
      var queryBuilder = supabase.from('users').select('*');

      if (searchTerm != null && searchTerm.isNotEmpty) {
        final st = '%${searchTerm.trim()}%';
        queryBuilder = queryBuilder.or('username.ilike.$st,email.ilike.$st,first_name.ilike.$st,last_name.ilike.$st,phone.ilike.$st');
      }

      final orderedQueryBuilder = queryBuilder.order('created_at', ascending: false);
      final response = await orderedQueryBuilder;

      if (!mounted) return;

      _users = response.map((data) => UserModel.fromMap(data as Map<String, dynamic>)).toList();
      if (_users.isEmpty && (searchTerm != null && searchTerm.isNotEmpty)) {
        _errorMessage = 'No users match your search criteria.';
      } else {
        _errorMessage = null;
      }
    } catch (e) {
      if (mounted) {
        debugPrint("[ManageUsersScreen] Error fetching users: $e");
        _errorMessage = "Error fetching users: ${e.toString()}";
        _users = [];
      }
    }
  }

  Future<void> _deleteUser(UserModel userToDelete) async {
    final canPerformAction = _isSuperAdmin || _adminPermissions.canDelete;
    if (!canPerformAction) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You do not have permission to delete users.')));
      return;
    }
    if (userToDelete.email == 'fiqraadmin@gmail.com') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Super Administrator account cannot be deleted.')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete user "${userToDelete.username}" (${userToDelete.email})? This is IRREVERSIBLE.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoading = true);
      try {
        await supabase.auth.admin.deleteUser(userToDelete.id);
        debugPrint("[ManageUsersScreen] User deleted from auth: ${userToDelete.id}");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User "${userToDelete.username}" deleted.'), backgroundColor: Colors.green));
        _fetchUsers(searchTerm: _searchTerm);
      } on AuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Auth Error: ${e.message}'), backgroundColor: Theme.of(context).colorScheme.error));
        debugPrint("[ManageUsersScreen] Delete Auth Error: ${e.message}");
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete Error: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error));
        debugPrint("[ManageUsersScreen] Delete Generic Error: ${e.toString()}");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showEditUserDialog(UserModel userToEdit) async {
    final canPerformAction = _isSuperAdmin || _adminPermissions.canEdit;
    if (!canPerformAction) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You do not have permission to edit users.')));
      return;
    }
    if (userToEdit.email == 'fiqraadmin@gmail.com' && !_isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only the Super Admin can edit their own profile.')));
      return;
    }

    _editUsernameController.text = userToEdit.username;
    _editFirstNameController.text = userToEdit.firstName;
    _editLastNameController.text = userToEdit.lastName;
    _editEmailController.text = userToEdit.email;
    _editPhoneController.text = userToEdit.phone ?? '';
    _editRoleController.value = _assignableRoles.contains(userToEdit.role) ? userToEdit.role : 'user';

    final bool? success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isDialogSaving = false;
        return StatefulBuilder(builder: (stfContext, stfSetState) {
          return AlertDialog(
            title: Text('Edit User: ${userToEdit.username}'),
            content: SingleChildScrollView(
              child: Form(
                key: _editFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(controller: _editEmailController, decoration: const InputDecoration(labelText: 'Email (Read-only)'), readOnly: true),
                    const SizedBox(height: 12),
                    TextFormField(controller: _editUsernameController, decoration: const InputDecoration(labelText: 'Username'), validator: (val) => (val == null || val.trim().isEmpty) ? 'Username required.' : (val.trim().length < 3 ? 'Min 3 chars.' : null), enabled: !isDialogSaving),
                    const SizedBox(height: 12),
                    TextFormField(controller: _editFirstNameController, decoration: const InputDecoration(labelText: 'First Name'), validator: (val) => (val == null || val.trim().isEmpty) ? 'First name required.' : null, enabled: !isDialogSaving),
                    const SizedBox(height: 12),
                    TextFormField(controller: _editLastNameController, decoration: const InputDecoration(labelText: 'Last Name'), validator: (val) => (val == null || val.trim().isEmpty) ? 'Last name required.' : null, enabled: !isDialogSaving),
                    const SizedBox(height: 12),
                    TextFormField(controller: _editPhoneController, decoration: const InputDecoration(labelText: 'Phone (Optional)'), keyboardType: TextInputType.phone, enabled: !isDialogSaving),
                    const SizedBox(height: 16),
                    ValueListenableBuilder<String>(
                        valueListenable: _editRoleController,
                        builder: (context, currentRole, child) {
                          bool canChangeRole = _isSuperAdmin && userToEdit.email != 'fiqraadmin@gmail.com';
                          if (userToEdit.email == 'fiqraadmin@gmail.com') canChangeRole = false;

                          return DropdownButtonFormField<String>(
                            value: currentRole,
                            decoration: const InputDecoration(labelText: 'Role', border: OutlineInputBorder()),
                            items: _assignableRoles.map((role) => DropdownMenuItem(value: role, child: Text(role.capitalizeFirst()))).toList(),
                            onChanged: isDialogSaving || !canChangeRole ? null : (value) { if (value != null) _editRoleController.value = value; },
                            validator: (val) => val == null || val.isEmpty ? 'Role required.' : null,
                          );
                        }),
                    if (userToEdit.email == 'fiqraadmin@gmail.com')
                      Padding(padding: const EdgeInsets.only(top: 8.0), child: Text('Super Admin role cannot be changed here.', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error))),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: isDialogSaving ? null : () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isDialogSaving ? null : () async {
                  if (_editFormKey.currentState!.validate()) {
                    stfSetState(() => isDialogSaving = true);
                    try {
                      final Map<String, dynamic> updatedProfileData = {
                        'username': _editUsernameController.text.trim(),
                        'first_name': _editFirstNameController.text.trim(),
                        'last_name': _editLastNameController.text.trim(),
                        'phone': _editPhoneController.text.trim().isEmpty ? null : _editPhoneController.text.trim(),
                      };

                      final newRole = _editRoleController.value;
                      bool roleChanged = userToEdit.role != newRole;

                      if (_isSuperAdmin && userToEdit.email != 'fiqraadmin@gmail.com') {
                        updatedProfileData['role'] = newRole;
                      } else if (roleChanged && userToEdit.email != 'fiqraadmin@gmail.com') {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('You cannot change user roles.'), backgroundColor: Colors.orange));
                        stfSetState(() => isDialogSaving = false);
                        return;
                      }

                      await supabase.from('users').update(updatedProfileData).eq('id', userToEdit.id);

                      if (_isSuperAdmin && roleChanged && userToEdit.email != 'fiqraadmin@gmail.com') {
                        try {
                          await supabase.auth.admin.updateUserById(
                            userToEdit.id,
                            attributes: AdminUserAttributes(userMetadata: {
                              ...(userToEdit.rawUserMetaData ?? {}), // Now uses updated UserModel
                              'role': newRole,
                              'username': updatedProfileData['username'],
                              'first_name': updatedProfileData['first_name'],
                              'last_name': updatedProfileData['last_name'],
                            }),
                          );
                          debugPrint("[ManageUsersScreen] Auth metadata updated for ${userToEdit.id}");
                        } on AuthException catch (authE) {
                          debugPrint("[ManageUsersScreen] Failed to update auth user metadata (role): ${authE.message}. Profile table still updated.");
                          if (mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Warning: Profile updated, auth role sync failed: ${authE.message}'), backgroundColor: Colors.orangeAccent));
                        }
                      }
                      if (mounted) Navigator.of(dialogContext).pop(true);
                    } catch (e) {
                      debugPrint("[ManageUsersScreen] Error updating user: $e");
                      if (mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Update failed: ${e.toString()}'), backgroundColor: Theme.of(dialogContext).colorScheme.error));
                    } finally {
                      if (mounted) stfSetState(() => isDialogSaving = false);
                    }
                  }
                },
                child: isDialogSaving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save Changes'),
              )
            ],
          );
        });
      },
    );

    if (success == true) {
      _fetchUsers(searchTerm: _searchTerm);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_isSuperAdmin && !_adminPermissions.canView && !_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Users')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage ?? 'Access Denied: You do not have permission to view users.',
              style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage All Users'),
        actions: [
          if (_isSuperAdmin || _adminPermissions.canGoToInviteScreen)
            IconButton(
              icon: const Icon(Icons.person_add_alt),
              tooltip: 'Invite or Add New User',
              onPressed: () => Navigator.pushNamed(context, AdminInviteUserScreen.routeName).then((_) {
                _fetchUsers(searchTerm: _searchTerm);
              }),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Users',
            onPressed: _isLoading ? null : () => _loadData(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 8.0),
            child: TextField(
              onChanged: (value) {
                if (mounted) {
                  setState(() => _searchTerm = value);
                  Future.delayed(const Duration(milliseconds: 400), () {
                    if (mounted && _searchTerm == value) {
                      _fetchUsers(searchTerm: value);
                    }
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'Search by name, email, username, phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                filled: true,
                fillColor: theme.inputDecorationTheme.fillColor ?? theme.cardColor,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null && _users.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error, fontSize: 16), textAlign: TextAlign.center)))
                : _users.isEmpty
                ? Center(child: Text(_searchTerm == null || _searchTerm!.isEmpty ? 'No users found in the system.' : 'No users match your search criteria.'))
                : ListView.separated(
              itemCount: _users.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 72, endIndent: 16),
              itemBuilder: (context, index) {
                final user = _users[index];
                final isThisSuperAdminUser = user.email == 'fiqraadmin@gmail.com';

                final bool canEditThisUser = (_isSuperAdmin || _adminPermissions.canEdit) && (!isThisSuperAdminUser || _isSuperAdmin);
                final bool canDeleteThisUser = (_isSuperAdmin || _adminPermissions.canDelete) && !isThisSuperAdminUser;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: Text(user.username.isNotEmpty ? user.username[0].toUpperCase() : (user.email.isNotEmpty ? user.email[0].toUpperCase() : '?')),
                  ),
                  title: Text(user.username.isNotEmpty ? user.username : '(No Username)', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${user.firstName} ${user.lastName}'),
                      Text(user.email, style: theme.textTheme.bodySmall),
                      if (user.phone != null && user.phone!.isNotEmpty)
                        Text('Phone: ${user.phone}', style: theme.textTheme.bodySmall),
                      Chip(
                        label: Text(user.role.capitalizeFirst()),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                        labelStyle: TextStyle(fontSize: 11, color: theme.colorScheme.onSecondaryContainer),
                        backgroundColor: theme.colorScheme.secondaryContainer.withOpacity(0.7),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                  trailing: (canEditThisUser || canDeleteThisUser)
                      ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit') _showEditUserDialog(user);
                      if (value == 'delete') _deleteUser(user);
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      if (canEditThisUser)
                        const PopupMenuItem<String>(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit Profile'))),
                      if (canDeleteThisUser)
                        PopupMenuItem<String>(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: theme.colorScheme.error), title: Text('Delete User', style: TextStyle(color: theme.colorScheme.error)))),
                    ],
                  )
                      : (isThisSuperAdminUser && _isSuperAdmin) // If it's the SA viewing their own profile
                      ? IconButton(icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary), tooltip: "Edit Super Admin Profile", onPressed: () => _showEditUserDialog(user))
                      : null, // No actions if no permission and not SA viewing self
                  onTap: canEditThisUser ? () => _showEditUserDialog(user) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Ensure this extension is in lib/utils/string_extensions.dart and this file imports it.
// Do NOT keep this extension definition here.
/*
extension StringCapitalizeExtension on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
  }
}
*/
