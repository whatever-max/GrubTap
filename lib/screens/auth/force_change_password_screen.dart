// lib/screens/auth/force_change_password_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:grubtap/services/session_service.dart'; // To get current user and role
import 'package:grubtap/main.dart'; // For AuthWrapper.routeName or similar initial route

class ForceChangePasswordScreen extends StatefulWidget {
  // Flag to know if this screen was reached due to a temporary password scenario
  final bool comesFromTempPassword;
  final String? tempToken; // Optional: If you implement a token-based verification for this flow

  const ForceChangePasswordScreen({
    super.key,
    required this.comesFromTempPassword,
    this.tempToken,
  });

  static const String routeName = '/force-change-password';

  @override
  State<ForceChangePasswordScreen> createState() => _ForceChangePasswordScreenState();
}

class _ForceChangePasswordScreenState extends State<ForceChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (supabase.auth.currentUser == null) {
      setState(() {
        _errorMessage = "No active user session. Please log in again.";
      });
      // Optionally navigate to login
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {await supabase.auth.updateUser(
      UserAttributes(password: _passwordController.text),
    );

    // IMPORTANT: After successful password change for a temp-password user,
    // you might want to update a flag in their user_metadata or your public.users table
    // to indicate they have set a real password.
    // E.g., user_metadata: {'requires_password_change': false}
    final currentUser = supabase.auth.currentUser;
    if (currentUser != null && widget.comesFromTempPassword) {
      // Create a copy of existing metadata or an empty map if null
      final Map<String, dynamic> existingMetadata = Map<String, dynamic>.from(currentUser.userMetadata ?? {});
      // Update the flag
      existingMetadata['requires_password_change'] = false;

      await supabase.auth.updateUser(UserAttributes(data: existingMetadata));
      debugPrint("[ForceChangePasswordScreen] 'requires_password_change' flag updated for user ${currentUser.id}");

      // Also update in your SessionService cache if applicable
      await SessionService.updateUserMetadataInCache(existingMetadata);
    }


    setState(() {
      _isLoading = false;
      _successMessage = 'Password changed successfully! You will be redirected.';
    });

    // Navigate to the appropriate dashboard or home screen
    Future.delayed(const Duration(seconds: 2), () async {
      if (mounted) {
        // Instead of AuthWrapper, directly determine the route based on the now-updated user
        final role = await SessionService.getUserRole(); // Re-fetch role if metadata changed
        String nextRoute = SessionService.getInitialRouteForRole(role);
        Navigator.of(context).pushNamedAndRemoveUntil(nextRoute, (route) => false);
      }
    });

    } on AuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to change password: ${e.message}";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "An unexpected error occurred: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.comesFromTempPassword ? 'Set Your Password' : 'Change Password'),
        automaticallyImplyLeading: !widget.comesFromTempPassword, // No back button if forced
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.comesFromTempPassword
                          ? 'Welcome! Please set a new password.'
                          : 'Change Your Password',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.comesFromTempPassword)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                        child: Text(
                          'For security, you must change the temporary password provided by the administrator.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    const SizedBox(height: 16),

                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_successMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          _successMessage!,
                          style: TextStyle(color: Colors.green.shade700, fontSize: 14, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),

                    if (_successMessage == null) ...[
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Enter a new password';
                          if (val.length < 6) return 'Password must be at least 6 characters';
                          return null;
                        },
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          prefixIcon: const Icon(Icons.check_circle_outline),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        obscureText: _obscureConfirmPassword,
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Confirm your new password';
                          if (val != _passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                        onFieldSubmitted: (_) => _isLoading ? null : _handleChangePassword(),
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 24),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                        onPressed: _handleChangePassword,
                        style: theme.elevatedButtonTheme.style,
                        child: Text(widget.comesFromTempPassword ? 'Set Password & Continue' : 'Update Password'),
                      ),
                    ],
                    if (widget.comesFromTempPassword && _successMessage == null && !_isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: TextButton(
                          onPressed: () async {
                            await SessionService.logout(); // Log out the user
                            // Navigate to login, AuthWrapper will handle the rest
                            Navigator.of(context).pushNamedAndRemoveUntil(AuthWrapper.routeName, (route) => false);
                          },
                          child: const Text('Logout (or skip for now - not recommended)'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
