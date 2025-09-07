// lib/screens/auth/reset_password_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:grubtap/screens/auth/login_screen.dart'; // To navigate after success

class ResetPasswordScreen extends StatefulWidget {
  // Optional: if you pass the access token directly via routing (less common for deep links)
  // final String? accessToken;

  // For deep linking, Supabase usually handles setting the session,
  // so we might not need to pass the token explicitly if the link opens the app
  // and Supabase client picks up the session from the URL fragment.
  const ResetPasswordScreen({super.key /*, this.accessToken */});

  static const String routeName = '/reset-password'; // For named navigation if needed

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
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
  void initState() {
    super.initState();
    // Supabase client automatically handles the session recovery from the URL fragment
    // when the app is opened via a password recovery deep link.
    // We just need to check if a user is available, implying the token was processed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (supabase.auth.currentUser == null) {
        // This might happen if the link was invalid, expired, or something went wrong
        // with Supabase picking up the session from the URL fragment.
        setState(() {
          _errorMessage = "Invalid or expired password reset link. Please request a new one.";
        });
        // Optionally, redirect to login after a delay
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
          } else if (mounted) {
            Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (supabase.auth.currentUser == null) {
      setState(() {
        _errorMessage = "No active session found. The reset link might be invalid or expired.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      setState(() {
        _isLoading = false;
        _successMessage = 'Password updated successfully! You can now log in with your new password.';
        // Clear fields or navigate away
      });

      // Navigate to login after a short delay
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
        }
      });

    } on AuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Failed to update password: ${e.message}";
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
        title: const Text('Set New Password'),
        automaticallyImplyLeading: supabase.auth.currentUser == null, // Show back button only if link was bad
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
                      'Create Your New Password',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (supabase.auth.currentUser == null && _errorMessage == null)
                      const Center(child: CircularProgressIndicator(key: ValueKey("loadingIndicator"))),

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

                    if (supabase.auth.currentUser != null && _successMessage == null) ...[
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
                        onFieldSubmitted: (_) => _isLoading ? null : _handleResetPassword(),
                        enabled: !_isLoading,
                      ),
                      const SizedBox(height: 24),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                        onPressed: _handleResetPassword,
                        style: theme.elevatedButtonTheme.style,
                        child: const Text('Update Password'),
                      ),
                    ],
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
