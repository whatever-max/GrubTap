// lib/screens/auth/role_selector_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:grubtap/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // For AuthException

class RoleSelectorScreen extends StatefulWidget {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String username;
  final VoidCallback onRoleSelected;

  const RoleSelectorScreen({
    super.key,
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.onRoleSelected,
  });

  @override
  State<RoleSelectorScreen> createState() => _RoleSelectorScreenState();
}

class _RoleSelectorScreenState extends State<RoleSelectorScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleRoleSelectionAndCompleteSignup(String selectedRole) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final AuthResponse authResponse = await _authService.completeSignupAndCreateProfile(
        email: widget.email,
        password: widget.password,
        firstName: widget.firstName,
        lastName: widget.lastName,
        username: widget.username,
        role: selectedRole,
      );

      if (!mounted) return;

      if (authResponse.user != null) {
        debugPrint("[RoleSelectorScreen] Signup completed with role '$selectedRole' for user ${authResponse.user!.id}. Calling onRoleSelected callback.");
        widget.onRoleSelected();
      } else {
        setState(() {
          _errorMessage = "Signup process failed. User not fully created. Please try again or contact support.";
        });
      }
    } on AuthException catch (e) {
      debugPrint("[RoleSelectorScreen] AuthException during role selection/signup for '$selectedRole': ${e.message}");
      if (mounted) {
        String displayError = "Signup Error: ${e.message}";
        if (e.message.toLowerCase().contains('user already registered')) {
          displayError = 'This email is already registered. Please login or use a different email.';
        }
        setState(() {
          _errorMessage = displayError;
        });
      }
    } catch (e) {
      debugPrint("[RoleSelectorScreen] Generic error during role selection/signup for '$selectedRole': $e");
      if (mounted) {
        setState(() {
          _errorMessage = "An unexpected error occurred: ${e.toString()}";
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
    final ThemeData theme = Theme.of(context);
    // Scaffold will inherit its white background from the theme set in main.dart
    return Scaffold(
      appBar: AppBar(
        // AppBar will use the theme's AppBarTheme (white background, dark foreground)
        title: const Text('Select Your Role'),
        // automaticallyImplyLeading: false, // Keep if you don't want a back button.
        // If SignupScreen pushes this, a back button might be desired.
        // For now, let's keep it as per your original code.
        automaticallyImplyLeading: false, // Or true, if you want a back button to SignupScreen
      ),
      // No backgroundColor: Colors.transparent needed here
      body: Center(
        child: SingleChildScrollView( // Added SingleChildScrollView for smaller screens
          padding: const EdgeInsets.all(24.0),
          child: Card( // Wrap the main content in a Card
            elevation: 4, // Add some shadow to lift it from the white background
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0), // Adjust padding as needed
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    "How will you be using GrubTap?",
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_outline),
                    label: const Text("Continue as User / Customer"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      // textStyle: const TextStyle(fontSize: 16), // Example to ensure button text size
                    ),
                    onPressed: _isLoading ? null : () => _handleRoleSelectionAndCompleteSignup("user"),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text("I represent a Food Company"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      // textStyle: const TextStyle(fontSize: 16),
                    ),
                    onPressed: _isLoading ? null : () => _handleRoleSelectionAndCompleteSignup("company"),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text("I am an Administrator"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      // textStyle: const TextStyle(fontSize: 16),
                    ),
                    onPressed: _isLoading ? null : () => _handleRoleSelectionAndCompleteSignup("admin"),
                  ),
                  const SizedBox(height: 30),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
