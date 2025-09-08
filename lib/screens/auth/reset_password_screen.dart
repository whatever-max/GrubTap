// lib/screens/auth/reset_password_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:grubtap/screens/auth/login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  static const String routeName = '/reset-password';
  final String? recoveryCodeFromArgs;
  final String? emailFromArgs;

  const ResetPasswordScreen({super.key, this.recoveryCodeFromArgs, this.emailFromArgs});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false; // For password update UI button state
  String? _errorMessage;
  String? _successMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final supabase = Supabase.instance.client;
  String? _processedRecoveryCode;
  String? _processedEmail;
  bool _initialCheckCompleted = false;
  bool _isExchangingCode = false; // For showing full screen loader

  @override
  void initState() {
    super.initState();
    debugPrint("[ResetPasswordScreen] initState called. recoveryCodeFromArgs: ${widget.recoveryCodeFromArgs}, emailFromArgs: ${widget.emailFromArgs}");

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      debugPrint("[ResetPasswordScreen] initState postFrameCallback started.");

      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      _processedRecoveryCode = widget.recoveryCodeFromArgs ?? args?['recoveryCode'];
      _processedEmail = widget.emailFromArgs ?? args?['email'];

      debugPrint("[ResetPasswordScreen] Processed recoveryCode: $_processedRecoveryCode, Processed email: $_processedEmail");

      // Scenario 1: User is already logged in (e.g., from a fragment link that auto-signed in)
      // This is important if the deep link itself contained a session fragment Supabase client could process.
      if (supabase.auth.currentUser != null) {
        debugPrint("[ResetPasswordScreen] User already authenticated: ${supabase.auth.currentUser!.id}. Ready for password update form.");
        if (mounted) {
          setState(() {
            _initialCheckCompleted = true;
            _isExchangingCode = false;
          });
        }
        return; // Exit early, no need to exchange code
      }

      // Scenario 2: No current user, but have code and email to try exchanging via Edge Function
      // This is expected if the link was myapp://password-reset?code=...&email=...
      if (_processedRecoveryCode != null && _processedEmail != null) {
        debugPrint("[ResetPasswordScreen] No current user. Attempting to exchange code '$_processedRecoveryCode' for email '$_processedEmail' via Edge Function.");
        if (mounted) {
          setState(() {
            _isExchangingCode = true; // Show loading screen
            _errorMessage = null;
          });
        }
        await _exchangeResetCodeViaEdgeFunction(_processedRecoveryCode!, _processedEmail!);
        // _exchangeResetCodeViaEdgeFunction will set _isExchangingCode = false and _initialCheckCompleted = true in its finally block
      }
      // Scenario 3: No current user, and NOT enough info for Edge Function call
      // (e.g. bad link, or expecting fragment which didn't work, or AuthWrapper didn't pass args)
      else {
        debugPrint("[ResetPasswordScreen] No current user, and code/email missing for Edge Function. This might be an invalid link or a fragment link that failed to process, or args not passed.");
        // Give a moment for Supabase client to potentially process a fragment if one existed (e.g. if link was #access_token=...)
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          if (supabase.auth.currentUser != null) {
            // Fragment link worked after all!
            debugPrint("[ResetPasswordScreen] Session established after delay (likely by fragment). User: ${supabase.auth.currentUser!.id}.");
            setState(() {
              _initialCheckCompleted = true;
              _isExchangingCode = false;
            });
          } else {
            // Still no user, definitely an issue with the link or how this screen was reached
            setState(() {
              _errorMessage = "Invalid or incomplete password reset link. Please try again.";
              _isExchangingCode = false;
              _initialCheckCompleted = true;
            });
            _redirectToLoginAfterDelay(isError: true);
          }
        }
      }
      debugPrint("[ResetPasswordScreen] initState postFrameCallback finished. InitialCheck: $_initialCheckCompleted, ExchangingCode: $_isExchangingCode, User: ${supabase.auth.currentUser?.id}");
    });
  }

  void _redirectToLoginAfterDelay({bool isError = false}) {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && (isError || _successMessage == null) && supabase.auth.currentUser == null) {
        Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
      }
    });
  }

  Future<void> _exchangeResetCodeViaEdgeFunction(String code, String email) async {
    debugPrint("[ResetPasswordScreen] Calling Edge Function 'exchange-reset-code' with code: $code, email: $email");
    try {
      final response = await supabase.functions.invoke(
        'exchange-reset-code',
        body: {'code': code, 'email': email},
      );

      debugPrint("[ResetPasswordScreen] Edge function 'exchange-reset-code' response status: ${response.status}, data: ${response.data}");

      if (response.status! >= 200 && response.status! < 300 && response.data != null) {
        final responseData = response.data as Map<String, dynamic>;
        final refreshToken = responseData['refreshToken'] as String?;

        if (refreshToken != null) {
          debugPrint("[ResetPasswordScreen] Edge function success. Setting session using received refresh token.");
          // setSession attempts to refresh the session using the provided token.
          // It is Future<void> and throws AuthException on failure.
          await supabase.auth.setSession(refreshToken);

          // After a successful setSession, supabase.auth.currentUser should be updated
          // by the onAuthStateChange listener (handled by SessionService).
          // We verify it here for immediate feedback.
          if (supabase.auth.currentUser != null) {
            debugPrint("[ResetPasswordScreen] Session established via Edge Function and setSession. User: ${supabase.auth.currentUser!.id}. Ready to update password.");
            if (mounted) {
              setState(() { _errorMessage = null; }); // Clear any previous error
            }
          } else {
            // This would be unexpected if setSession didn't throw but also didn't set currentUser
            debugPrint("[ResetPasswordScreen] setSession call seemed to succeed but supabase.auth.currentUser is still null.");
            throw Exception("Failed to establish session using setSession: Current user is null after call.");
          }
        } else {
          throw Exception("Missing refreshToken from Edge Function response data.");
        }
      } else {
        final errorMsg = (response.data is Map ? response.data['error']?.toString() : response.data?.toString()) ?? "Unknown error from exchange function.";
        throw Exception("Server error from 'exchange-reset-code': '$errorMsg' (Status: ${response.status})");
      }
    } on AuthException catch (e) { // Catch AuthException specifically (e.g., from setSession if token is bad)
      debugPrint("[ResetPasswordScreen] AuthException in _exchangeResetCodeViaEdgeFunction (likely from setSession): ${e.message}");
      if (mounted) {
        setState(() {
          _errorMessage = "Could not verify reset link: ${e.message}";
        });
        _redirectToLoginAfterDelay(isError: true);
      }
    } catch (e) { // Catch other general exceptions
      debugPrint("[ResetPasswordScreen] Generic error in _exchangeResetCodeViaEdgeFunction: ${e.toString()}");
      if (mounted) {
        setState(() {
          _errorMessage = "Could not verify reset link: ${e.toString().split('Exception: ').last}";
        });
        _redirectToLoginAfterDelay(isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExchangingCode = false;
          _initialCheckCompleted = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    debugPrint("[ResetPasswordScreen] dispose called.");
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    debugPrint("[ResetPasswordScreen] _handleResetPassword called.");

    if (supabase.auth.currentUser == null) {
      debugPrint("[ResetPasswordScreen] _handleResetPassword: No active Supabase session. Cannot update password.");
      setState(() {
        _errorMessage = "No active session found. The reset link/code failed to process or has expired. Please try requesting a new link.";
        _isLoading = false;
      });
      return;
    }
    debugPrint("[ResetPasswordScreen] _handleResetPassword: Active session for user ${supabase.auth.currentUser!.id}. Updating password.");

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
      debugPrint("[ResetPasswordScreen] AuthException during password update: ${e.message}");
      if (mounted) {
        setState(() { _isLoading = false; _errorMessage = "Failed to update password: ${e.message}"; });
      }
    } catch (e) {
      debugPrint("[ResetPasswordScreen] Generic error during password update: ${e.toString()}");
      if (mounted) {
        setState(() { _isLoading = false; _errorMessage = "An unexpected error occurred: ${e.toString()}"; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    debugPrint("[ResetPasswordScreen] build called. _isExchangingCode: $_isExchangingCode, _initialCheckCompleted: $_initialCheckCompleted, currentUser: ${supabase.auth.currentUser?.id}, error: $_errorMessage");

    if (_isExchangingCode || !_initialCheckCompleted) {
      // Show loading if actively exchanging code OR if initial checks are not yet complete
      return Scaffold(
        appBar: AppBar(title: const Text('Verifying Link...')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(key: ValueKey("ResetPasswordExchangeLoading")),
              SizedBox(height: 16),
              Text("Verifying your reset link...")
            ],
          ),
        ),
      );
    }

    // After initial checks and any code exchange attempt:
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set New Password'),
        automaticallyImplyLeading: supabase.auth.currentUser == null && _errorMessage != null && _successMessage == null,
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
                  children: <Widget>[
                    Text(
                      'Create Your New Password',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    if (_errorMessage != null && _successMessage == null)
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
                      // Password input fields
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
                        enabled: !_isLoading, // Form fields enabled if not doing network op for password update
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
                      if (_isLoading) // This _isLoading is for the "Update Password" button press
                        const Center(child: CircularProgressIndicator(key: ValueKey("ResetPasswordUpdating")))
                      else
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleResetPassword,
                          child: const Text('Update Password'),
                        ),
                    ]
                    else if (_errorMessage != null && supabase.auth.currentUser == null && _successMessage == null) ...[
                      // Error shown and no user, show Go to Login
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
                        },
                        child: const Text('Go to Login'),
                      ),
                    ]
                    else if (_initialCheckCompleted && supabase.auth.currentUser == null && _errorMessage == null && _successMessage == null) ...[
                        // Fallback: Initial checks done, no user, no error yet (should be rare if link was bad and error was set)
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
                          child: Text(
                            "Could not process the password reset link. Please try requesting a new link or contact support.",
                            style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
                          },
                          child: const Text('Go to Login'),
                        ),
                      ]
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
