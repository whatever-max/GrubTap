// lib/screens/admin/admin_invite_user_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/foundation.dart';
// import 'dart:math'; // For Option A: Random Password
import 'package:grubtap/utils/string_extensions.dart';

class AdminInviteUserScreen extends StatefulWidget {
  static const String routeName = '/admin-invite-user';

  const AdminInviteUserScreen({super.key});

  @override
  State<AdminInviteUserScreen> createState() => _AdminInviteUserScreenState();
}

class _AdminInviteUserScreenState extends State<AdminInviteUserScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  final _inviteFormKey = GlobalKey<FormState>();
  final _addFormKey = GlobalKey<FormState>();

  final _inviteEmailController = TextEditingController();
  final _inviteRoleController = ValueNotifier<String>('user');
  final _inviteUsernameController = TextEditingController();
  final _inviteFirstNameController = TextEditingController();
  final _inviteLastNameController = TextEditingController();
  final _inviteCompanyNameController = TextEditingController();

  final _addEmailController = TextEditingController();
  // Password controller removed - will be auto-generated or fixed
  final _addUsernameController = TextEditingController();
  final _addFirstNameController = TextEditingController();
  final _addLastNameController = TextEditingController();
  final _addRoleController = ValueNotifier<String>('user');
  final _addCompanyNameController = TextEditingController();

  bool _isInviting = false;
  bool _isAddingUser = false;
  String? _generatedPasswordForDisplay; // To show admin the temp password

  final List<String> _userRoles = ['user', 'company', 'admin'];
  static const String _defaultTemporaryPassword = "TempPassword123!"; // Option B

  // For Option A: Random Password
  /*
  String _generateRandomPassword({int length = 12}) {
    const String lower = 'abcdefghijklmnopqrstuvwxyz';
    const String upper = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    const String numbers = '0123456789';
    const String symbols = '!@#\$%^&*()_+[]{}|';
    final String allChars = '$lower$upper$numbers$symbols';
    final Random random = Random.secure();
    return List.generate(length, (index) => allChars[random.nextInt(allChars.length)]).join();
  }
  */

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
    _addUsernameController.dispose();
    _addFirstNameController.dispose();
    _addLastNameController.dispose();
    _addCompanyNameController.dispose();
    _addRoleController.dispose();
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

    final email = _inviteEmailController.text.trim();
    final role = _inviteRoleController.value;
    final username = _inviteUsernameController.text.trim();
    final firstName = _inviteFirstNameController.text.trim();
    final lastName = _inviteLastNameController.text.trim();
    final companyName = _inviteCompanyNameController.text.trim();

    final Map<String, dynamic> userMetadata = {
      'role': role,
      if (username.isNotEmpty) 'username': username,
      if (firstName.isNotEmpty) 'first_name': firstName,
      if (lastName.isNotEmpty) 'last_name': lastName,
      if (role == 'company' && companyName.isNotEmpty) 'initial_company_name': companyName,
    };

    try {
      await supabase.auth.admin.inviteUserByEmail(email, data: userMetadata);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invitation sent to $email.'), backgroundColor: Colors.green));
        _clearInviteForm();
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invite Error: ${e.message}'), backgroundColor: Theme.of(context).colorScheme.error));
      debugPrint("[AdminInviteScreen] Invite AuthError: ${e.message}");
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An unexpected error occurred during invite: $e'), backgroundColor: Theme.of(context).colorScheme.error));
      debugPrint("[AdminInviteScreen] Generic Invite Error: $e");
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  Future<void> _addUser() async {
    if (!_addFormKey.currentState!.validate()) return;
    setState(() => _isAddingUser = true);

    final email = _addEmailController.text.trim();
    final username = _addUsernameController.text.trim();
    final firstName = _addFirstNameController.text.trim();
    final lastName = _addLastNameController.text.trim();
    final role = _addRoleController.value;
    final companyName = _addCompanyNameController.text.trim();

    // final String temporaryPassword = _generateRandomPassword(); // Option A
    const String temporaryPassword = _defaultTemporaryPassword; // Option B

    try {
      final userResponse = await supabase.auth.admin.createUser(AdminUserAttributes(
        email: email,
        password: temporaryPassword,
        emailConfirm: true,
        userMetadata: {'username': username, 'first_name': firstName, 'last_name': lastName, 'role': role},
      ));

      final newAuthUser = userResponse.user;
      if (newAuthUser == null) throw Exception("Failed to create user in auth system.");
      debugPrint("[AdminAddUser] Auth user created: ${newAuthUser.id}");

      await supabase.from('users').insert({
        'id': newAuthUser.id, 'email': email, 'username': username,
        'first_name': firstName, 'last_name': lastName, 'role': role,
      });
      debugPrint("[AdminAddUser] User profile created in public.users: ${newAuthUser.id}");

      if (role == 'company') {
        if (companyName.isEmpty) {
          await supabase.auth.admin.deleteUser(newAuthUser.id);
          await supabase.from('users').delete().eq('id', newAuthUser.id);
          throw Exception("Company name is required for 'company' role users.");
        }
        await supabase.from('companies').insert({'name': companyName, 'created_by': newAuthUser.id});
        debugPrint("[AdminAddUser] Company profile created for ${newAuthUser.id}");
      }

      if (mounted) {
        setState(() => _generatedPasswordForDisplay = temporaryPassword); // For Option A or B if you want to display it
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('User "$username" added! Temp Pwd: $temporaryPassword'), backgroundColor: Colors.green));
        _clearAddUserForm(); // Clear form but generated password might still be shown via _generatedPasswordForDisplay state
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add User Auth Error: ${e.message}'), backgroundColor: Theme.of(context).colorScheme.error));
      debugPrint("[AdminAddUser] AuthError: ${e.message}");
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('An unexpected error occurred: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error));
      debugPrint("[AdminAddUser] Generic Error: $e");
    } finally {
      if (mounted) setState(() => _isAddingUser = false);
    }
  }

  Widget _buildRoleDropdown(ValueNotifier<String> controller) {
    return ValueListenableBuilder<String>(
      valueListenable: controller,
      builder: (context, value, child) {
        return DropdownButtonFormField<String>(
          value: value,
          decoration: const InputDecoration(labelText: 'Select Role', border: OutlineInputBorder()),
          items: _userRoles.map((role) => DropdownMenuItem<String>(value: role, child: Text(role.capitalizeFirst()))).toList(),
          onChanged: (newValue) => controller.value = newValue ?? controller.value,
          validator: (value) => value == null || value.isEmpty ? 'Please select a role.' : null,
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
        bottom: TabBar(controller: _tabController, tabs: const [Tab(text: 'Invite User'), Tab(text: 'Add User Directly')]),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Invite User Tab
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
                  const Text('An invitation link will be sent. They will set their own password.', textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  TextFormField(controller: _inviteEmailController, decoration: const InputDecoration(labelText: 'User Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress, validator: (val) => val == null || !EmailValidator.validate(val.trim()) ? 'Enter a valid email' : null, enabled: !_isInviting),
                  const SizedBox(height: 16),
                  _buildRoleDropdown(_inviteRoleController),
                  const SizedBox(height: 16),
                  TextFormField(controller: _inviteUsernameController, decoration: const InputDecoration(labelText: 'Username (Optional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_circle_outlined)), validator: (val) => (val != null && val.trim().isNotEmpty && val.trim().length < 3) ? 'Min 3 chars.' : null, enabled: !_isInviting),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _inviteFirstNameController, decoration: const InputDecoration(labelText: 'First Name (Optional)', border: OutlineInputBorder()), enabled: !_isInviting)),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: _inviteLastNameController, decoration: const InputDecoration(labelText: 'Last Name (Optional)', border: OutlineInputBorder()), enabled: !_isInviting)),
                  ]),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String>(
                      valueListenable: _inviteRoleController,
                      builder: (context, role, child) {
                        if (role == 'company') return TextFormField(controller: _inviteCompanyNameController, decoration: const InputDecoration(labelText: 'Company Name (For Company Invite)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business_outlined)), enabled: !_isInviting);
                        return const SizedBox.shrink();
                      }),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isInviting ? null : _sendInvitation,
                    icon: _isInviting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.send_outlined),
                    label: Text(_isInviting ? 'Sending...' : 'Send Invitation'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  ),
                ],
              ),
            ),
          ),
          // Add User Directly Tab
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
                  const Text('User created immediately. A temporary password will be used.', textAlign: TextAlign.center), // Updated text
                  const SizedBox(height: 24),
                  TextFormField(controller: _addEmailController, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email_outlined)), keyboardType: TextInputType.emailAddress, validator: (val) => val == null || !EmailValidator.validate(val.trim()) ? 'Enter a valid email' : null, enabled: !_isAddingUser),
                  const SizedBox(height: 12),
                  // Password field removed, uses _defaultTemporaryPassword
                  TextFormField(controller: _addUsernameController, decoration: const InputDecoration(labelText: 'Username', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_circle_outlined)), validator: (val) => (val == null || val.trim().isEmpty) ? 'Username is required.' : (val.trim().length < 3 ? 'Min 3 chars.' : null), enabled: !_isAddingUser),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _addFirstNameController, decoration: const InputDecoration(labelText: 'First Name', border: OutlineInputBorder()), validator: (val) => (val == null || val.trim().isEmpty) ? 'First name is required.' : null, enabled: !_isAddingUser)),
                    const SizedBox(width: 10),
                    Expanded(child: TextFormField(controller: _addLastNameController, decoration: const InputDecoration(labelText: 'Last Name', border: OutlineInputBorder()), validator: (val) => (val == null || val.trim().isEmpty) ? 'Last name is required.' : null, enabled: !_isAddingUser)),
                  ]),
                  const SizedBox(height: 16),
                  _buildRoleDropdown(_addRoleController),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String>(
                      valueListenable: _addRoleController,
                      builder: (context, role, child) {
                        if (role == 'company') return TextFormField(controller: _addCompanyNameController, decoration: const InputDecoration(labelText: 'Company Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business_outlined)), validator: (val) => (role == 'company' && (val == null || val.trim().isEmpty)) ? 'Company name required.' : null, enabled: !_isAddingUser);
                        return const SizedBox.shrink();
                      }),
                  if (_generatedPasswordForDisplay != null) ...[ // Display generated password
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer.withOpacity(0.5), borderRadius: BorderRadius.circular(8)),
                      child: Column(
                        children: [
                          Text('User created with temporary password:', style: theme.textTheme.labelLarge),
                          SelectableText(_generatedPasswordForDisplay!, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                          const SizedBox(height: 4),
                          const Text('Please share this with the user and advise them to change it upon first login.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isAddingUser ? null : _addUser,
                    icon: _isAddingUser ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Icon(Icons.person_add_outlined),
                    label: Text(_isAddingUser ? 'Adding...' : 'Add User'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.green.shade700),
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



