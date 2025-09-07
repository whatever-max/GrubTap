// lib/screens/auth/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:email_validator/email_validator.dart';
import 'package:grubtap/screens/auth/role_selector_screen.dart';
import 'package:grubtap/screens/auth/login_screen.dart';

class SignupScreen extends StatefulWidget {
  static const String routeName = '/signup';

  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _proceedToRoleSelection() {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    if (!_formKey.currentState!.validate()) {
      setState(() => _isLoading = false);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _isLoading = false;
      });
      _showStyledLocalError('Passwords do not match.');
      return;
    }

    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String username = _usernameController.text.trim(); // Still trim for consistency

    debugPrint('[SignupScreen] Data collected locally. Navigating to RoleSelectorScreen.');
    setState(() => _isLoading = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoleSelectorScreen(
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          username: username,
          onRoleSelected: () {
            debugPrint("[SignupScreen Flow] Role selected and full signup completed from RoleSelectorScreen.");
            if (mounted && Navigator.canPop(context)) {
              Navigator.of(context).popUntil((route) => route.settings.name == LoginScreen.routeName || route.isFirst);
            }
          },
        ),
      ),
    );
  }

  void _showStyledLocalError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: BackButton(
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
        ),
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
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Join GrubTap!',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create an account to start your journey.',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'First Name', prefixIcon: Icon(Icons.person_outline)),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter first name';
                        if (val.trim().length < 2) return 'At least 2 characters';
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Last Name', prefixIcon: Icon(Icons.person_outline)),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter last name';
                        if (val.trim().length < 2) return 'At least 2 characters';
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.alternate_email)),
                      // **** MODIFIED VALIDATOR FOR USERNAME ****
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter username';
                        if (val.trim().length < 3) return 'Username must be at least 3 characters';
                        // No more validation for spaces or specific characters
                        return null;
                      },
                      // **** END MODIFICATION ****
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined)),
                      keyboardType: TextInputType.emailAddress,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter email';
                        if (!EmailValidator.validate(val.trim())) return 'Enter a valid email address';
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      obscureText: _obscurePassword,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Enter a password';
                        if (val.length < 6) return 'Password must be at least 6 characters';
                        return null;
                      },
                      textInputAction: TextInputAction.next,
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password',
                        prefixIcon: const Icon(Icons.check_circle_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                      obscureText: _obscureConfirmPassword,
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Confirm your password';
                        if (val != _passwordController.text) return 'Passwords do not match';
                        return null;
                      },
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _isLoading ? null : _proceedToRoleSelection(),
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 24),
                    if (_errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error, fontSize: 14), textAlign: TextAlign.center),
                      ),
                    _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                      icon: const Icon(Icons.arrow_forward_ios_rounded),
                      label: const Text('Next: Select Role'),
                      style: theme.elevatedButtonTheme.style,
                      onPressed: _proceedToRoleSelection,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Already have an account?", style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        TextButton(
                          onPressed: _isLoading ? null : () {
                            if (Navigator.canPop(context)) Navigator.pop(context); // Go back to LoginScreen
                          },
                          child: Text('Login Now', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                        ),
                      ],
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
