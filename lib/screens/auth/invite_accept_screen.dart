// lib/screens/auth/invite_accept_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart'; // Ensure this import is correct

class InviteAcceptScreen extends StatefulWidget {
  // **** UPDATED ROUTE NAME ****
  static const String routeName = '/invite'; // Changed from '/invite-accept'
  final String? tokenFromLink;

  const InviteAcceptScreen({super.key, this.tokenFromLink});

  @override
  State<InviteAcceptScreen> createState() => _InviteAcceptScreenState();
}

class _InviteAcceptScreenState extends State<InviteAcceptScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _inviteToken;

  @override
  void initState() {
    super.initState();
    _inviteToken = widget.tokenFromLink;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args.containsKey('token') && args['token'] != null) {
        if (mounted) {
          setState(() {
            _inviteToken = args['token'];
          });
        }
        debugPrint("[InviteAcceptScreen] Received token via arguments: $_inviteToken");
      } else if (_inviteToken != null) {
        debugPrint("[InviteAcceptScreen] Using token from constructor: $_inviteToken");
      }
      else {
        debugPrint("[InviteAcceptScreen] No invite token found.");
        if (mounted) {
          setState(() {
            _errorMessage = "Invalid or missing invitation link. Please check the link and try again.";
          });
        }
      }
    });
  }

  Future<void> _setNewPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (Supabase.instance.client.auth.currentUser == null) {
      if(mounted) {
        setState(() {
          _errorMessage = "No active session. Please ensure the invitation link is correct or try logging in again if you've already set a password.";
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );

      if (response.user != null) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(
            data: {
              'requires_password_change': false,
              'temp_password_active': false,
            },
          ),
        );
        debugPrint("[InviteAcceptScreen] Password updated and metadata flags cleared for user: ${response.user!.id}");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password set successfully! Please log in.'), backgroundColor: Colors.green),
          );
          Navigator.of(context).pushNamedAndRemoveUntil(LoginScreen.routeName, (route) => false);
        }
      } else {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Supabase.instance.client.auth.currentUser == null && _errorMessage == null && !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if(mounted && _errorMessage == null) {
          setState(() {
            _errorMessage = "Invalid or expired invitation. Please request a new invite or contact support.";
          });
        }
      });
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: (_errorMessage != null && !_isLoading)
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
              : Form(
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
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password.';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12.0),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock_person_outlined)),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password.';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24.0),
                if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else
                  ElevatedButton(
                    onPressed: Supabase.instance.client.auth.currentUser != null ? _setNewPassword : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Supabase.instance.client.auth.currentUser != null
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                    ),
                    child: const Text('Set Password and Activate'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

