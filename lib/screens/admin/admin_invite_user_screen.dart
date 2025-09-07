// lib/screens/admin/admin_invite_user_screen.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:grubtap/utils/string_extensions.dart';

class AdminInviteUserScreen extends StatefulWidget {
  static const String routeName = '/admin-invite-user';
  const AdminInviteUserScreen({super.key});

  @override
  State<AdminInviteUserScreen> createState() => _AdminInviteUserScreenState();
}

class _AdminInviteUserScreenState extends State<AdminInviteUserScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final supabase = Supabase.instance.client;

  final _inviteFormKey = GlobalKey<FormState>();
  final _inviteEmailController = TextEditingController();
  final _inviteRoleController = ValueNotifier<String>('user');
  final _inviteUsernameController = TextEditingController();
  final _inviteFirstNameController = TextEditingController();
  final _inviteLastNameController = TextEditingController();
  final _inviteCompanyNameController = TextEditingController();
  bool _isInviting = false;

  final _addFormKey = GlobalKey<FormState>();
  final _addEmailController = TextEditingController();
  final _addPasswordController = TextEditingController();
  final _addUsernameController = TextEditingController();
  final _addFirstNameController = TextEditingController();
  final _addLastNameController = TextEditingController();
  final _addRoleController = ValueNotifier<String>('user');
  final _addCompanyNameController = TextEditingController();
  bool _isAddingUser = false;
  String? _generatedPasswordForDisplay;

  final List<String> _userRoles = ['user', 'company', 'admin'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _inviteEmailController.dispose();
    _inviteUsernameController.dispose();
    _inviteFirstNameController.dispose();
    _inviteLastNameController.dispose();
    _inviteCompanyNameController.dispose();
    _inviteRoleController.dispose();
    _addEmailController.dispose();
    _addPasswordController.dispose();
    _addUsernameController.dispose();
    _addFirstNameController.dispose();
    _addLastNameController.dispose();
    _addRoleController.dispose();
    _addCompanyNameController.dispose();
    super.dispose();
  }

  void _clearInviteForm() {
    _inviteFormKey.currentState?.reset();
    _inviteEmailController.clear();
    _inviteUsernameController.clear();
    _inviteFirstNameController.clear();
    _inviteLastNameController.clear();
    _inviteCompanyNameController.clear();
    _inviteRoleController.value = 'user';
  }

  void _clearAddUserForm() {
    _addFormKey.currentState?.reset();
    _addEmailController.clear();
    _addPasswordController.clear();
    _addUsernameController.clear();
    _addFirstNameController.clear();
    _addLastNameController.clear();
    _addCompanyNameController.clear();
    _addRoleController.value = 'user';
    setState(() {
      _generatedPasswordForDisplay = null;
    });
  }

  Future<void> _sendInvitation() async {
    if (!_inviteFormKey.currentState!.validate()) return;
    setState(() => _isInviting = true);

    final payload = {
      'email': _inviteEmailController.text.trim(),
      'role': _inviteRoleController.value,
      'username': _inviteUsernameController.text.trim().nullIfEmpty,
      'firstName': _inviteFirstNameController.text.trim().nullIfEmpty,
      'lastName': _inviteLastNameController.text.trim().nullIfEmpty,
      'companyName': _inviteRoleController.value == 'company'
          ? _inviteCompanyNameController.text.trim().nullIfEmpty
          : null,
    }..removeWhere((_, v) => v == null);

    try {
      final response = await supabase.functions.invoke('invite-user', body: payload);
      final success = response.status >= 200 && response.status < 300;

      if (!success) {
        final msg = (response.data is Map && response.data['message'] != null)
            ? response.data['message'].toString()
            : 'Error inviting user.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$msg (Status: ${response.status})'),
                backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
        return;
      }

      if (mounted) {
        final message = (response.data is Map && response.data['message'] != null)
            ? response.data['message'].toString()
            : 'Invitation sent.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
        _clearInviteForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  Future<void> _addUser() async {
    if (!_addFormKey.currentState!.validate()) return;
    setState(() => _isAddingUser = true);

    final tempPwd = _addPasswordController.text.trim();
    if (tempPwd.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Temporary password required.'),
              backgroundColor: Colors.redAccent),
        );
      }
      setState(() => _isAddingUser = false);
      return;
    }

    final payload = {
      'email': _addEmailController.text.trim(),
      'password': tempPwd,
      'username': _addUsernameController.text.trim(),
      'firstName': _addFirstNameController.text.trim(),
      'lastName': _addLastNameController.text.trim(),
      'role': _addRoleController.value,
      'companyName': _addRoleController.value == 'company'
          ? _addCompanyNameController.text.trim().nullIfEmpty
          : null,
    }..removeWhere((_, v) => v == null);

    try {
      final response = await supabase.functions.invoke('add-user-directly', body: payload);
      final success = response.status >= 200 && response.status < 300;

      if (!success) {
        final msg = (response.data is Map && response.data['message'] != null)
            ? response.data['message'].toString()
            : 'Error adding user.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$msg (Status: ${response.status})'),
                backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
        return;
      }

      if (mounted) {
        setState(() => _generatedPasswordForDisplay = tempPwd);
        final message = (response.data is Map && response.data['message'] != null)
            ? response.data['message'].toString()
            : 'User added.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
        );
        _clearAddUserForm();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unexpected error: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingUser = false);
    }
  }

  Widget _buildRoleDropdown(ValueNotifier<String> controller) {
    return ValueListenableBuilder<String>(
      valueListenable: controller,
      builder: (context, value, _) {
        return DropdownButtonFormField<String>(
          value: value,
          decoration: const InputDecoration(
              labelText: 'Select Role', border: OutlineInputBorder()),
          items: _userRoles
              .map((role) => DropdownMenuItem<String>(
            value: role,
            child: Text(role.capitalizeFirst()),
          ))
              .toList(),
          onChanged: (val) => controller.value = val ?? controller.value,
          validator: (val) => (val == null || val.isEmpty)
              ? 'Please select a role.' : null,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Invite User (Email Link)'),
            Tab(text: 'Add User Directly (Temp Pwd)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Invite User UI
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _inviteFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.mail_outline, size: 70, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Invite New User', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('An invitation link will be sent. They will set their own password.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _inviteEmailController,
                    decoration: const InputDecoration(
                        labelText: 'User Email', border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => val == null || !EmailValidator.validate(val.trim())
                        ? 'Enter a valid email' : null,
                    enabled: !_isInviting,
                  ),
                  const SizedBox(height: 16),
                  _buildRoleDropdown(_inviteRoleController),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _inviteUsernameController,
                    decoration: const InputDecoration(
                        labelText: 'Username (Optional)', border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_circle_outlined)),
                    validator: (val) =>
                    val != null && val.trim().isNotEmpty && val.trim().length < 3
                        ? 'Min 3 characters' : null,
                    enabled: !_isInviting,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _inviteFirstNameController,
                          decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
                          enabled: !_isInviting,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _inviteLastNameController,
                          decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
                          enabled: !_isInviting,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String>(
                    valueListenable: _inviteRoleController,
                    builder: (context, role, _) {
                      if (role == 'company') {
                        return Padding(
                          padding: const EdgeInsets.only(top: 0),
                          child: TextFormField(
                            controller: _inviteCompanyNameController,
                            decoration: const InputDecoration(
                              labelText: 'Company Name (For Company Role)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business_outlined),
                            ),
                            validator: (val) => val == null || val.trim().isEmpty
                                ? 'Company name required.' : null,
                            enabled: !_isInviting,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isInviting ? null : _sendInvitation,
                    icon: _isInviting
                        ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Icon(Icons.send_outlined),
                    label: Text(_isInviting ? 'Sending...' : 'Send Invitation'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  ),
                ],
              ),
            ),
          ),

          // Add User UI
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _addFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.person_add_alt_1_outlined, size: 70, color: Colors.green.shade700),
                  const SizedBox(height: 16),
                  Text('Add User Manually', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  const Text('User is created immediately. They must change the temp password on first login.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _addEmailController,
                    decoration: const InputDecoration(
                        labelText: 'Email', border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined)),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) => val == null || !EmailValidator.validate(val.trim())
                        ? 'Enter a valid email' : null,
                    enabled: !_isAddingUser,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addPasswordController,
                    decoration: const InputDecoration(
                        labelText: 'Temporary Password', border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.password_outlined)),
                    obscureText: true,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Password required.';
                      if (val.trim().length < 6) return 'Minimum 6 characters.';
                      return null;
                    },
                    enabled: !_isAddingUser,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _addUsernameController,
                    decoration: const InputDecoration(
                        labelText: 'Username', border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_circle_outlined)),
                    validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Username required.' : null,
                    enabled: !_isAddingUser,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _addFirstNameController,
                          decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()),
                          validator: (val) =>
                          val == null || val.trim().isEmpty ? 'First name required.' : null,
                          enabled: !_isAddingUser,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _addLastNameController,
                          decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()),
                          validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Last name required.' : null,
                          enabled: !_isAddingUser,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildRoleDropdown(_addRoleController),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String>(
                    valueListenable: _addRoleController,
                    builder: (context, role, _) {
                      if (role == 'company') {
                        return Padding(
                          padding: const EdgeInsets.only(top: 0),
                          child: TextFormField(
                            controller: _addCompanyNameController,
                            decoration: const InputDecoration(
                              labelText: 'Company Name (For Company Role)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business_outlined),
                            ),
                            validator: (val) =>
                            val == null || val.trim().isEmpty ? 'Company name required.' : null,
                            enabled: !_isAddingUser,
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                  if (_generatedPasswordForDisplay != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('User created! Share this temporary password:',
                              style: theme.textTheme.labelLarge, textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          SelectableText(
                            _generatedPasswordForDisplay!,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text('Advise them to change it upon first login.',
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isAddingUser ? null : _addUser,
                    icon: _isAddingUser
                        ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                        : const Icon(Icons.person_add_outlined),
                    label: Text(_isAddingUser ? 'Adding...' : 'Add User Directly'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
