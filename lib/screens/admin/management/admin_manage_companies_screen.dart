// lib/screens/admin/management/admin_manage_companies_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:grubtap/models/company_model.dart';
import 'package:grubtap/services/session_service.dart';
import 'package:grubtap/utils/string_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class AdminManageCompaniesScreen extends StatefulWidget {
  static const String routeName = '/admin-manage-companies';
  const AdminManageCompaniesScreen({super.key});

  @override
  State<AdminManageCompaniesScreen> createState() => _AdminManageCompaniesScreenState();
}

class _AdminManageCompaniesScreenState extends State<AdminManageCompaniesScreen> {
  final supabase = Supabase.instance.client;
  List<CompanyModel> _companies = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _searchTerm;

  final _currentUserEmail = SessionService.getCurrentUser()?.email;
  bool get _isSuperAdmin => _currentUserEmail == 'fiqraadmin@gmail.com';

  bool _canViewCompanies = false;
  bool _canEditCompanies = false;
  bool _canDeleteCompanies = false;
  bool _canAddCompanies = false;

  final _companyFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _logoUrlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _logoUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _errorMessage = null; });

    if (!_isSuperAdmin) {
      await _fetchAdminCompanyPermissions();
    } else {
      _canViewCompanies = true;
      _canEditCompanies = true;
      _canDeleteCompanies = true;
      _canAddCompanies = true;
    }

    if (_isSuperAdmin || _canViewCompanies) {
      await _fetchCompanies(searchTerm: _searchTerm);
    } else {
      _companies = [];
      _errorMessage = "You do not have permission to view companies.";
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchAdminCompanyPermissions() async {
    if (_isSuperAdmin || SessionService.getCurrentUser() == null) {
      // Default to no permissions if not super admin and no current user
      if (mounted) {
        setState(() {
          _canViewCompanies = false; _canEditCompanies = false; _canDeleteCompanies = false; _canAddCompanies = false;
        });
      }
      return;
    }
    try {
      final response = await supabase
          .from('admin_permissions')
          .select('can_view, can_edit, can_delete, can_invite') // Using can_invite as can_add for companies
          .eq('admin_user_id', SessionService.getCurrentUser()!.id)
          .eq('permission_type', 'MANAGE_COMPANIES')
          .maybeSingle();

      if (mounted) {
        if (response != null) {
          setState(() {
            _canViewCompanies = response['can_view'] ?? false;
            _canEditCompanies = response['can_edit'] ?? false;
            _canDeleteCompanies = response['can_delete'] ?? false;
            _canAddCompanies = response['can_invite'] ?? false;
          });
        } else {
          setState(() { // Explicitly set to false if no row found
            _canViewCompanies = false; _canEditCompanies = false; _canDeleteCompanies = false; _canAddCompanies = false;
          });
        }
      }
    } catch (e) {
      debugPrint("[ManageCompaniesScreen] Error fetching permissions: $e");
      if (mounted) {
        setState(() {
          _errorMessage = "Error loading your company permissions.";
          _canViewCompanies = false; _canEditCompanies = false; _canDeleteCompanies = false; _canAddCompanies = false;
        });
      }
    }
  }

  Future<void> _fetchCompanies({String? searchTerm}) async {
    // Permission check for viewing is handled in _loadData
    try {
      var queryBuilder = supabase
          .from('companies')
          .select('*, users (id, username)'); // users is the joined table alias for created_by user details

      if (searchTerm != null && searchTerm.isNotEmpty) {
        final st = '%${searchTerm.trim()}%';
        queryBuilder = queryBuilder.or('name.ilike.$st,description.ilike.$st,users.username.ilike.$st');
      }

      final orderedQueryBuilder = queryBuilder.order('name', ascending: true);
      final response = await orderedQueryBuilder;

      if (!mounted) return;
      _companies = response.map((data) => CompanyModel.fromMap(data as Map<String, dynamic>)).toList();

      if (_companies.isEmpty && (searchTerm != null && searchTerm.isNotEmpty)) {
        _errorMessage = 'No companies match your search criteria.';
      } else {
        _errorMessage = null;
      }
    } catch (e) {
      if (mounted) {
        debugPrint("[ManageCompaniesScreen] Error fetching companies: $e");
        _errorMessage = "Error fetching companies: ${e.toString()}";
        _companies = [];
      }
    }
  }

  void _clearFormControllers() {
    _nameController.clear();
    _descriptionController.clear();
    _logoUrlController.clear();
  }

  Future<void> _showAddEditCompanyDialog({CompanyModel? companyToEdit}) async {
    final bool isEditMode = companyToEdit != null;
    final bool canPerform = isEditMode ? (_isSuperAdmin || _canEditCompanies) : (_isSuperAdmin || _canAddCompanies);

    if (!canPerform) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You do not have permission to ${isEditMode ? "edit" : "add"} companies.')));
      return;
    }

    _clearFormControllers();
    if (isEditMode) {
      _nameController.text = companyToEdit!.name;
      _descriptionController.text = companyToEdit.description ?? '';
      _logoUrlController.text = companyToEdit.logoUrl ?? '';
    }

    final bool? success = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        bool isDialogSaving = false;
        return StatefulBuilder(builder: (stfContext, stfSetState) {
          return AlertDialog(
            title: Text(isEditMode ? 'Edit Company' : 'Add New Company'),
            content: SingleChildScrollView(
              child: Form(
                key: _companyFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Company Name*'),
                      validator: (val) => (val == null || val.trim().isEmpty) ? 'Company name is required.' : null,
                      enabled: !isDialogSaving,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Description (Optional)'),
                      maxLines: 3,
                      enabled: !isDialogSaving,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _logoUrlController,
                      decoration: const InputDecoration(labelText: 'Logo URL (Optional)'),
                      keyboardType: TextInputType.url,
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty) {
                          if (!Uri.tryParse(val.trim())!.isAbsolute) {
                            return 'Please enter a valid URL.';
                          }
                        }
                        return null;
                      },
                      enabled: !isDialogSaving,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: isDialogSaving ? null : () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isDialogSaving ? null : () async {
                  if (_companyFormKey.currentState!.validate()) {
                    stfSetState(() => isDialogSaving = true);
                    final currentAdminUserId = SessionService.getCurrentUser()?.id;

                    if (!isEditMode && currentAdminUserId == null) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(const SnackBar(content: Text('Error: Admin session not found.'), backgroundColor: Colors.red));
                      stfSetState(() => isDialogSaving = false);
                      return;
                    }

                    try {
                      if (isEditMode) {
                        final updatedCompany = CompanyModel(
                          id: companyToEdit!.id,
                          name: _nameController.text.trim(),
                          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                          logoUrl: _logoUrlController.text.trim().isEmpty ? null : _logoUrlController.text.trim(),
                          createdAt: companyToEdit.createdAt, // Preserve original
                          createdByUserId: companyToEdit.createdByUserId, // Preserve original
                          createdByUsername: companyToEdit.createdByUsername, // Preserve original
                        );
                        await supabase.from('companies').update(updatedCompany.toMapForUpdate()).eq('id', companyToEdit.id);
                      } else {
                        final newCompany = CompanyModel(
                          id: '', // DB generates UUID
                          name: _nameController.text.trim(),
                          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                          logoUrl: _logoUrlController.text.trim().isEmpty ? null : _logoUrlController.text.trim(),
                          createdAt: DateTime.now(), // DB default for created_at is better
                          createdByUserId: currentAdminUserId,
                          // createdByUsername will be populated by DB join on fetch if needed
                        );
                        await supabase.from('companies').insert(newCompany.toMapForInsert(currentAdminUserId!));
                      }
                      if (mounted) Navigator.of(dialogContext).pop(true);
                    } catch (e) {
                      debugPrint("[CompanyDialog] Error saving company: $e");
                      if (mounted) ScaffoldMessenger.of(dialogContext).showSnackBar(SnackBar(content: Text('Save failed: ${e.toString()}'), backgroundColor: Theme.of(dialogContext).colorScheme.error));
                    } finally {
                      if (mounted) stfSetState(() => isDialogSaving = false);
                    }
                  }
                },
                child: isDialogSaving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
              )
            ],
          );
        });
      },
    );

    if (success == true) {
      _loadData();
    }
  }

  Future<void> _deleteCompany(CompanyModel companyToDelete) async {
    final bool canPerform = _isSuperAdmin || _canDeleteCompanies;
    if (!canPerform) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You do not have permission to delete companies.')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete company "${companyToDelete.name}"? This action cannot be undone and may affect associated data.'),
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
        await supabase.from('companies').delete().eq('id', companyToDelete.id);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Company "${companyToDelete.name}" deleted.'), backgroundColor: Colors.green));
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete Error: ${e.toString()}'), backgroundColor: Theme.of(context).colorScheme.error));
        debugPrint("[ManageCompaniesScreen] Delete Error: ${e.toString()}");
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final DateFormat dateFormat = DateFormat.yMMMd();

    if (!_isSuperAdmin && !_canViewCompanies && !_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Manage Companies')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage ?? 'Access Denied. You do not have permission to view companies.',
              style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Companies'),
        actions: [
          if (_isSuperAdmin || _canAddCompanies)
            IconButton(
              icon: const Icon(Icons.add_business_outlined),
              tooltip: 'Add New Company',
              onPressed: _isLoading ? null : () => _showAddEditCompanyDialog(),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Companies',
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
                    if (mounted && _searchTerm == value) _fetchCompanies(searchTerm: value);
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'Search by name, description, creator...',
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
                : _errorMessage != null && _companies.isEmpty
                ? Center(child: Padding(padding: const EdgeInsets.all(16), child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error, fontSize: 16), textAlign: TextAlign.center)))
                : _companies.isEmpty
                ? Center(child: Text(_searchTerm == null || _searchTerm!.isEmpty ? 'No companies found.' : 'No companies match your search criteria.'))
                : ListView.separated(
              itemCount: _companies.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final company = _companies[index];
                final bool canEditThis = _isSuperAdmin || _canEditCompanies;
                final bool canDeleteThis = _isSuperAdmin || _canDeleteCompanies;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.tertiaryContainer,
                    foregroundColor: theme.colorScheme.onTertiaryContainer,
                    backgroundImage: company.logoUrl != null && company.logoUrl!.isNotEmpty && Uri.tryParse(company.logoUrl!)?.isAbsolute == true
                        ? NetworkImage(company.logoUrl!)
                        : null,
                    child: (company.logoUrl == null || company.logoUrl!.isEmpty || Uri.tryParse(company.logoUrl!)?.isAbsolute == false) && company.name.isNotEmpty
                        ? Text(company.name[0].toUpperCase())
                        : null,
                  ),
                  title: Text(company.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (company.description != null && company.description!.isNotEmpty)
                        Text(company.description!, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('Creator: ${company.createdByUsername ?? "N/A"}', style: theme.textTheme.bodySmall),
                      Text('Added: ${dateFormat.format(company.createdAt.toLocal())}', style: theme.textTheme.bodySmall),
                    ],
                  ),
                  trailing: (canEditThis || canDeleteThis) ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert),
                    onSelected: (value) {
                      if (value == 'edit') _showAddEditCompanyDialog(companyToEdit: company);
                      if (value == 'delete') _deleteCompany(company);
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      if (canEditThis)
                        const PopupMenuItem<String>(value: 'edit', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Edit Details'))),
                      if (canDeleteThis)
                        PopupMenuItem<String>(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: theme.colorScheme.error), title: Text('Delete Company', style: TextStyle(color: theme.colorScheme.error)))),
                    ],
                  ) : null,
                  onTap: canEditThis ? () => _showAddEditCompanyDialog(companyToEdit: company) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
