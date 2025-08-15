import 'package:flutter/material.dart';
import 'package:grubtap/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _auth = AuthService();

  void _send() async {
    if (_email.text.trim().isEmpty) return;
    try {
      await _auth.sendPasswordResetEmail(_email.text.trim());
      _show('Check your email for reset link');
      Navigator.pop(context);
    } catch (e) {
      print('Reset error: $e');
      _show('Failed to send link');
    }
  }

  void _show(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Reset Password')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Enter your email to reset your password'),
            TextField(controller: _email, decoration: InputDecoration(labelText: 'Email')),
            SizedBox(height: 20),
            ElevatedButton(onPressed: _send, child: Text('Send Reset Link')),
          ],
        ),
      ),
    );
  }
}
