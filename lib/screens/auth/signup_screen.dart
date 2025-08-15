import 'package:flutter/material.dart';
import 'package:grubtap/screens/auth/role_selector_screen.dart';
import 'package:grubtap/services/auth_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _isLoading = false;

  void _signup() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        _showMessage('Passwords do not match');
        return;
      }

      setState(() => _isLoading = true);

      try {
        final response = await _authService.signUpUser(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          userData: {
            'email': _emailController.text.trim(),
            'first_name': _firstNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
            'username': _usernameController.text.trim(),
            'role': 'user',
          },
        );

        if (response.user != null) {
          _showMessage('Signup successful! Redirecting...');
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => RoleSelectorScreen()),
          );
        } else {
          _showMessage('Signup failed');
        }
      } catch (e) {
        _showMessage('Signup error: $e');
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: InputDecoration(labelText: 'First Name'),
                validator: (val) => val!.isEmpty ? 'Enter first name' : null,
              ),
              TextFormField(
                controller: _lastNameController,
                decoration: InputDecoration(labelText: 'Last Name'),
                validator: (val) => val!.isEmpty ? 'Enter last name' : null,
              ),
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(labelText: 'Username'),
                validator: (val) => val!.isEmpty ? 'Enter username' : null,
              ),
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                validator: (val) => val!.isEmpty ? 'Enter email' : null,
              ),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Password'),
                validator: (val) => val!.length < 6 ? 'Min 6 chars' : null,
              ),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(labelText: 'Confirm Password'),
                validator: (val) => val!.isEmpty ? 'Confirm password' : null,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _signup,
                child: _isLoading ? CircularProgressIndicator() : Text('Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
