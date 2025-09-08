// lib/screens/auth/invite_accept_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart'; // Ensure this import is correct

class InviteAcceptScreen extends StatefulWidget {
  static const String routeName = '/invite';
  // We no longer expect a specific token via arguments if the fragment handles session
  // final String? tokenFromLink;

  const InviteAcceptScreen({super.key /*, this.tokenFromLink */});

  @override
  State<InviteAcceptScreen> createState() => _InviteAcceptScreenState();
}

class _InviteAcceptScreenState extends State<InviteAcceptScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _initialCheckDone = false;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    debugPrint("[InviteAcceptScreen] initState called.");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      debugPrint("[InviteAcceptScreen] initState postFrameCallback started.");

      // For invites, the Supabase client should automatically handle the session
      // from the URL fragment (#access_token=...&type=invite).
      // We just need to check if a user is available after the client has had a chance.
      if (supabase.auth.currentUser == null) {
        debugPrint("[InviteAcceptScreen] initState: No active Supabase user session found (currentUser is null). Invite link might be invalid, expired, or session not yet processed from fragment.");
        if (mounted) {
          setState(() {
            _errorMessage = "Invalid or expired invitation. Please check the link or contact support.";
            _initialCheckDone = true;
          });
          // Optionally, redirect to login after a delay if error persists
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted && _errorMessage != null && supabase.auth.currentUser == null) {
              Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
            }
          });
        }
      } else {
        debugPrint("[InviteAcceptScreen] initState: Active Supabase user session found: ${supabase.auth.currentUser!.id}. User is ready to set password.");
        if (mounted) {
          setState(() {
            _initialCheckDone = true;
          });
        }
      }
    });
  }

  Future<void> _setNewPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    // Critical check: Session must be active
    if (supabase.auth.currentUser == null) {
      if(mounted) {
        setState(() {
          _errorMessage = "No active session. Please ensure the invitation link is correct or try again.";
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await supabase.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (response.user != null) {
        // Optionally update metadata if needed (e.g., clear invite-specific flags)
        // await supabase.auth.updateUser(
        //   UserAttributes(
        //     data: {
        //       'requires_password_change': false, // Example
        //       'temp_password_active': false,   // Example
        //       'invite_accepted_at': DateTime.now().toIso8601String(), // Example
        //     },
        //   ),
        // );
        debugPrint("[InviteAcceptScreen] Password updated successfully for user: ${response.user!.id}");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account activated! Password set successfully. Please log in.'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
        }
      } else {
        // This case should be rare if updateUser didn't throw AuthException but returned null user
        throw Exception("Failed to update user password. User object was null after update attempt.");
      }
    } on AuthException catch (e) {
      debugPrint("[InviteAcceptScreen] AuthException setting password: ${e.message}");
      if (mounted) {
        setState(() {
          _errorMessage = "Error setting password: ${e.message}";
        });
      }
    } catch (e) {
      debugPrint("[InviteAcceptScreen] Generic error setting password: $e");
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
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    debugPrint("[InviteAcceptScreen] dispose called.");
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint("[InviteAcceptScreen] build called. InitialCheckDone: $_initialCheckDone, Error: $_errorMessage, User: ${supabase.auth.currentUser?.id}");

    if (!_initialCheckDone && _errorMessage == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Complete Your Account')),
        body: const Center(child: CircularProgressIndicator(key: ValueKey("InviteInitialLoading"))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: (_errorMessage != null) // Simplified condition: if there's an error, show error UI
              ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 50),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
                },
                child: const Text('Go to Login'),
              )
            ],
          )
              : (supabase.auth.currentUser != null) // Show form only if session is active and no error
              ? Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Set Your Password',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Create a secure password to activate your account.',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24.0),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_outline)),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter a password.';
                    if (value.length < 6) return 'Password must be at least 6 characters.';
                    return null;
                  },
                ),
                const SizedBox(height: 12.0),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_person_outlined)),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please confirm your password.';
                    if (value != _passwordController.text) return 'Passwords do not match.';
                    return null;
                  },
                ),
                const SizedBox(height: 24.0),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    onPressed: _setNewPassword, // Enabled if currentUser is not null
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      // backgroundColor will use theme default if not disabled
                    ),
                    child: const Text('Set Password and Activate'),
                  ),
              ],
            ),
          )
              : const Center(child: CircularProgressIndicator(key: ValueKey("InviteWaitingForSession"))), // Fallback if no error but no user yet
        ),
      ),
    );
  }
}
