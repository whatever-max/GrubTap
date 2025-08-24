// lib/screens/auth/role_selector_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:grubtap/services/auth_service.dart'; // <<< YOU NEED THIS
import 'package:supabase_flutter/supabase_flutter.dart'; // For AuthException

class RoleSelectorScreen extends StatefulWidget {
  // Data passed from SignupScreen - THESE ARE NOW REQUIRED
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String username;

  final VoidCallback onRoleSelected; // Callback for AuthWrapper

  const RoleSelectorScreen({
    super.key,
    required this.email, // <<< ADDED
    required this.password, // <<< ADDED
    required this.firstName, // <<< ADDED
    required this.lastName, // <<< ADDED
    required this.username, // <<< ADDED
    required this.onRoleSelected,
  });

  @override
  State<RoleSelectorScreen> createState() => _RoleSelectorScreenState();
}

class _RoleSelectorScreenState extends State<RoleSelectorScreen> {
  final AuthService _authService = AuthService(); // <<< INSTANCE OF AuthService
  bool _isLoading = false;
  String? _errorMessage;

  // Renamed method to be more descriptive
  Future<void> _handleRoleSelectionAndCompleteSignup(String selectedRole) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use the data passed from SignupScreen via widget properties
      // AND call AuthService.completeSignupAndCreateProfile
      final AuthResponse authResponse = await _authService.completeSignupAndCreateProfile(
        email: widget.email,         // Use widget.email
        password: widget.password,   // Use widget.password
        firstName: widget.firstName, // Use widget.firstName
        lastName: widget.lastName,   // Use widget.lastName
        username: widget.username,   // Use widget.username
        role: selectedRole,          // The role chosen by the user
      );

      if (!mounted) return;

      if (authResponse.user != null) {
        debugPrint("[RoleSelectorScreen] Signup completed with role '$selectedRole' for user ${authResponse.user!.id}. Calling onRoleSelected callback.");
        widget.onRoleSelected(); // Notify AuthWrapper
      } else {
        // This case implies authService.completeSignupAndCreateProfile did not throw
        // but also didn't return a user, which is unusual.
        setState(() {
          _errorMessage = "Signup process failed. User not fully created. Please try again or contact support.";
        });
      }
    } on AuthException catch (e) {
      debugPrint("[RoleSelectorScreen] AuthException during role selection/signup for '$selectedRole': ${e.message}");
      if (mounted) {
        String displayError = "Signup Error: ${e.message}";
        // Check for specific error message for already registered user
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
    // YOUR UI IS PRESERVED
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Your Role', style: TextStyle(color: theme.appBarTheme.foregroundColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.transparent,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                "How will you be using GrubTap?",
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_outline),
                label: const Text("Continue as User / Customer"),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                // Calls the new method
                onPressed: _isLoading ? null : () => _handleRoleSelectionAndCompleteSignup("user"),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.storefront_outlined),
                label: const Text("I represent a Food Company"),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                // Calls the new method
                onPressed: _isLoading ? null : () => _handleRoleSelectionAndCompleteSignup("company"),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text("I am an Administrator"),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                // Calls the new method
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
    );
  }
}
