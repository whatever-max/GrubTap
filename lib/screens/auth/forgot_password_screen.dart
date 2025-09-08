// lib/screens/auth/forgot_password_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:email_validator/email_validator.dart';

class ForgotPasswordScreen extends StatefulWidget {
  static const String routeName = '/forgot-password';
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  final supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendPasswordResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();

    setState(() => _isLoading = true);
    String? anError;

    try {
      // Construct the redirectTo URL for your app, including the email.
      // This MUST match an entry in your Supabase Dashboard "Redirect URLs"
      // and the intent-filter in your AndroidManifest.xml for the host "password-reset".
      final String redirectTo = 'myapp://password-reset?email=${Uri.encodeComponent(email)}';
      debugPrint("[ForgotPasswordScreen] Attempting to send password reset. redirectTo: $redirectTo FOR EMAIL: $email");

      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: redirectTo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset link sent! Check your email to open the link in the app.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } on AuthException catch (e) {
      debugPrint("[ForgotPasswordScreen] AuthException: ${e.message}");
      anError = 'Error: ${e.message}';
    } catch (e) {
      debugPrint("[ForgotPasswordScreen] Generic Exception: ${e.toString()}");
      anError = 'An unexpected error occurred: ${e.toString()}';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        if (anError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(anError),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
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
                      'Forgot Your Password?',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Enter your email address below. We\'ll send you a link to reset your password in the app.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Please enter your email';
                        if (!EmailValidator.validate(val.trim())) return 'Please enter a valid email';
                        return null;
                      },
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                      onPressed: _sendPasswordResetEmail,
                      child: const Text('Send Reset Link'),
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
