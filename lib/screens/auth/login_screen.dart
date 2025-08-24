// lib/screens/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:flutter/foundation.dart';
import 'package:grubtap/screens/auth/forgot_password_screen.dart';
import 'package:grubtap/screens/auth/signup_screen.dart';
import 'package:grubtap/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login'; // Essential for routing

  final String? initialErrorMessage;

  const LoginScreen({
    super.key,
    this.initialErrorMessage,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.initialErrorMessage != null && widget.initialErrorMessage!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _errorMessage = widget.initialErrorMessage;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      debugPrint('[LoginScreen] Attempting login with email: $email');

      final response = await _authService.loginUser(
        email: email,
        password: password,
      );

      if (response.user != null) {
        debugPrint('[LoginScreen] Supabase login success for: ${response.user!.email}');
        // AuthWrapper will now handle navigation based on the new auth state and role.
      } else {
        // This case should be rare if AuthService throws exceptions for login failures.
        debugPrint('[LoginScreen] Login attempt returned no user and no exception.');
        if (mounted) {
          setState(() {
            _errorMessage = 'Invalid email or password. Please try again.';
          });
        }
      }
    } catch (e) {
      debugPrint('[LoginScreen] Login error: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().contains("Invalid login credentials")
              ? 'Invalid email or password. Please try again.'
              : 'An error occurred during login. Please try again later.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Your UI from the previous prompt for LoginScreen is good.
    // Re-pasting the structure for completeness.
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Welcome Back!', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Login to continue your GrubTap experience.', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined, color: theme.inputDecorationTheme.prefixIconColor), hintText: 'you@example.com'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Please enter your email';
                      if (!EmailValidator.validate(val.trim())) return 'Please enter a valid email';
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'Password', prefixIcon: Icon(Icons.lock_outline, color: theme.inputDecorationTheme.prefixIconColor)),
                    validator: (val) => val == null || val.isEmpty ? 'Please enter your password' : null,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _isLoading ? null : _login(),
                    enabled: !_isLoading,
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                      child: const Text("Forgot Password?"),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_errorMessage != null && _errorMessage!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error, fontSize: 14), textAlign: TextAlign.center),
                    ),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: theme.elevatedButtonTheme.style,
                    child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Login'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Don't have an account?", style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                        child: Text("Sign Up Now", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
