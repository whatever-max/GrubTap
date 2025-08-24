// lib/screens/auth/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:email_validator/email_validator.dart';
import 'package:grubtap/screens/auth/role_selector_screen.dart'; // Will navigate to this
import 'package:grubtap/screens/auth/login_screen.dart'; // For popUntil

// AuthService is NOT directly used here for signup in this corrected flow.
// RoleSelectorScreen will use AuthService.completeSignupAndCreateProfile.

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

  bool _isLoading = false; // For the "Next: Select Role" button's loading state
  String? _errorMessage; // For local form validation errors (e.g., password mismatch)
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

  // Renamed from _signup to reflect its new purpose
  void _proceedToRoleSelection() {
    setState(() {
      _errorMessage = null; // Clear previous local errors
      _isLoading = true;    // Show loading indicator on the button
    });

    if (!_formKey.currentState!.validate()) {
      setState(() => _isLoading = false); // Stop loading if form is invalid
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
        _isLoading = false; // Stop loading
      });
      return;
    }

    // All local client-side validations passed. Collect data.
    final String email = _emailController.text.trim();
    final String password = _passwordController.text; // Pass raw password
    final String firstName = _firstNameController.text.trim();
    final String lastName = _lastNameController.text.trim();
    final String username = _usernameController.text.trim();

    debugPrint('[SignupScreen] Data collected locally. Navigating to RoleSelectorScreen.');
    setState(() => _isLoading = false); // Stop loading animation before navigating

    // Navigate to RoleSelectorScreen, passing all collected user details.
    // RoleSelectorScreen will then handle the actual account creation and profile insertion
    // by calling AuthService.completeSignupAndCreateProfile.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoleSelectorScreen(
          // Pass all necessary data for signup
          email: email,
          password: password,
          firstName: firstName,
          lastName: lastName,
          username: username,
          // This callback is crucial. RoleSelectorScreen will call it
          // after it successfully completes the signup and profile creation.
          onRoleSelected: () {
            debugPrint("[SignupScreen Flow] Role selected and full signup completed from RoleSelectorScreen.");
            // After RoleSelectorScreen completes its task (which includes calling AuthService),
            // we pop back. AuthWrapper will then detect the newly authenticated user with a role.
            if (Navigator.canPop(context)) {
              // Pop RoleSelectorScreen and SignupScreen, returning to where AuthWrapper can react.
              // Often, this means popping back to the LoginScreen or the root if appropriate.
              Navigator.of(context).popUntil((route) => route.settings.name == LoginScreen.routeName || route.isFirst);
            }
          },
        ),
      ),
    );
  }

  // This method is now only for local form errors (like password mismatch).
  // Actual signup success/error messages are handled by RoleSelectorScreen.
  void _showStyledLocalError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(10, 5, 10, 10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // UI Structure is based on your previously provided clean version.
    return Scaffold(
      backgroundColor: Colors.transparent, // For GlobalBackground compatibility
      appBar: AppBar(
        title: Text('Create Account', style: TextStyle(color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimaryContainer)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onPrimaryContainer),
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
                  decoration: InputDecoration(labelText: 'First Name', prefixIcon: Icon(Icons.person_outline, color: theme.inputDecorationTheme.prefixIconColor)),
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
                  decoration: InputDecoration(labelText: 'Last Name', prefixIcon: Icon(Icons.person_outline, color: theme.inputDecorationTheme.prefixIconColor)),
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
                  decoration: InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.alternate_email, color: theme.inputDecorationTheme.prefixIconColor)),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter username';
                    if (val.trim().length < 3) return 'At least 3 characters';
                    if (val.contains(' ')) return 'No spaces allowed';
                    if (!RegExp(r"^[a-zA-Z0-9_-]+$").hasMatch(val.trim())) return 'Letters, numbers, _, - only';
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined, color: theme.inputDecorationTheme.prefixIconColor)),
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
                    prefixIcon: Icon(Icons.lock_outline, color: theme.inputDecorationTheme.prefixIconColor),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: theme.colorScheme.onSurfaceVariant),
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
                    prefixIcon: Icon(Icons.check_circle_outline, color: theme.inputDecorationTheme.prefixIconColor),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: theme.colorScheme.onSurfaceVariant),
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
                  icon: const Icon(Icons.arrow_forward_ios_rounded), // Icon indicating "next step"
                  label: const Text('Next: Select Role'),
                  style: theme.elevatedButtonTheme.style,
                  onPressed: _proceedToRoleSelection, // Calls the corrected method
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
    );
  }
}
