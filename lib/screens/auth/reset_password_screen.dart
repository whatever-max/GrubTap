// lib/screens/auth/reset_password_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:grubtap/screens/auth/login_screen.dart'; // To navigate after success

class ResetPasswordScreen extends StatefulWidget {
  static const String routeName = '/reset-password';
  final String? recoveryCodeFromArgs; // To receive the code from constructor (less common for routes)

  const ResetPasswordScreen({super.key, this.recoveryCodeFromArgs});

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
  String? _processedRecoveryCode; // Store the code if received
  bool _initialCheckCompleted = false; // To control initial loading/error display

  @override
  void initState() {
    super.initState();
    debugPrint("[ResetPasswordScreen] initState called.");

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      debugPrint("[ResetPasswordScreen] initState postFrameCallback started.");

      String? codeFromArgs;
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (widget.recoveryCodeFromArgs != null) { // Primarily for direct instantiation
        codeFromArgs = widget.recoveryCodeFromArgs;
        debugPrint("[ResetPasswordScreen] Received recoveryCode from widget constructor: $codeFromArgs");
      } else if (args != null && args.containsKey('recoveryCode')) {
        codeFromArgs = args['recoveryCode'] as String?;
        debugPrint("[ResetPasswordScreen] Received recoveryCode from ModalRoute arguments: $codeFromArgs");
      }

      if (codeFromArgs != null && codeFromArgs.isNotEmpty) {
        _processedRecoveryCode = codeFromArgs;
        debugPrint("[ResetPasswordScreen] Stored recoveryCode: $_processedRecoveryCode. Will rely on Supabase client auto-processing or current session.");
      }

      if (supabase.auth.currentUser == null) {
        debugPrint("[ResetPasswordScreen] initState: No active Supabase user session found (currentUser is null). Link/code might be invalid, expired, or not yet processed by Supabase client.");
        if (mounted) {
          setState(() {
            _errorMessage = "Invalid or expired password reset link/code. Please request a new one or ensure the link is correct.";
          });
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted && _errorMessage != null && supabase.auth.currentUser == null) {
              Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
            }
          });
        }
      } else {
        debugPrint("[ResetPasswordScreen] initState: Active Supabase user session found: ${supabase.auth.currentUser!.id}. Ready for password update.");
      }

      if (mounted) {
        setState(() {
          _initialCheckCompleted = true;
        });
      }
      debugPrint("[ResetPasswordScreen] initState postFrameCallback finished. Initial check completed: $_initialCheckCompleted");
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    debugPrint("[ResetPasswordScreen] dispose called.");
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    debugPrint("[ResetPasswordScreen] _handleResetPassword called.");

    if (supabase.auth.currentUser == null) {
      debugPrint("[ResetPasswordScreen] _handleResetPassword: No active Supabase session (currentUser is null). Cannot update password.");
      setState(() {
        _errorMessage = "No active session found. The reset link/code might be invalid, expired, or failed to process. Please try requesting a new link.";
      });
      return;
    }
    debugPrint("[ResetPasswordScreen] _handleResetPassword: Active session for user ${supabase.auth.currentUser!.id}. Proceeding with password update.");

    setState(() { _isLoading = true; _errorMessage = null; _successMessage = null; });

    try {
      await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      debugPrint("[ResetPasswordScreen] Password update successful for user ${supabase.auth.currentUser!.id}.");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _successMessage = 'Password updated successfully! You can now log in with your new password.';
        });
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
          }
        });
      }
    } on AuthException catch (e) {
      debugPrint("[ResetPasswordScreen] AuthException during password update for user ${supabase.auth.currentUser?.id}: ${e.message}");
      if (mounted) {
        setState(() { _isLoading = false; _errorMessage = "Failed to update password: ${e.message}"; });
      }
    } catch (e) {
      debugPrint("[ResetPasswordScreen] Generic error during password update for user ${supabase.auth.currentUser?.id}: ${e.toString()}");
      if (mounted) {
        setState(() { _isLoading = false; _errorMessage = "An unexpected error occurred: ${e.toString()}"; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    debugPrint("[ResetPasswordScreen] build called. Initial check completed: $_initialCheckCompleted, Error: $_errorMessage, Success: $_successMessage, User: ${supabase.auth.currentUser?.id}");

    if (!_initialCheckCompleted && _errorMessage == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Set New Password')),
        body: const Center(child: CircularProgressIndicator(key: ValueKey("ResetPasswordInitialLoading"))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set New Password'),
        automaticallyImplyLeading: supabase.auth.currentUser == null && _errorMessage != null,
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
                  children: <Widget>[ // Added <Widget> for clarity, though not strictly needed
                    Text(
                      'Create Your New Password',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                      textAlign: TextAlign.center,
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

                    if (_successMessage == null && (supabase.auth.currentUser != null || (_initialCheckCompleted && _errorMessage == null))) ...[
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
                        enabled: !_isLoading && supabase.auth.currentUser != null,
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
                        onFieldSubmitted: (_) => (_isLoading || supabase.auth.currentUser == null) ? null : _handleResetPassword(),
                        enabled: !_isLoading && supabase.auth.currentUser != null,
                      ),
                      const SizedBox(height: 24),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        ElevatedButton(
                          onPressed: (_isLoading || supabase.auth.currentUser == null) ? null : _handleResetPassword,
                          style: theme.elevatedButtonTheme.style?.copyWith(
                            backgroundColor: MaterialStateProperty.resolveWith<Color?>(
                                  (Set<MaterialState> states) {
                                if (states.contains(MaterialState.disabled)) return Colors.grey.shade400;
                                return theme.elevatedButtonTheme.style?.backgroundColor?.resolve(states);
                              },
                            ),
                          ),
                          child: const Text('Update Password'),
                        ),
                    ]
                    // Corrected the else-if structure here
                    else if (_errorMessage != null && _successMessage == null) ...[
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
                        },
                        child: const Text('Go to Login'),
                      ),
                    ]
                    else if (supabase.auth.currentUser == null && _errorMessage == null && _initialCheckCompleted)
                      // This is a single widget, no need for ...[] if it's the only thing in the else block
                        Padding( // This is the widget for this condition
                          padding: const EdgeInsets.only(top: 16.0, bottom: 16.0), // Added top padding
                          child: Text(
                            "Could not establish a session for password reset. Please try requesting a new link or contact support if the problem persists.",
                            style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    // Ensure all conditional blocks are properly structured as part of the children list
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
