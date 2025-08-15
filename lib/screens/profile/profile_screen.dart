import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: const [
            CircleAvatar(radius: 50, child: Icon(Icons.person, size: 60)),
            SizedBox(height: 16),
            TextField(decoration: InputDecoration(labelText: 'Username')),
            TextField(decoration: InputDecoration(labelText: 'Phone')),
            SizedBox(height: 16),
            ElevatedButton(onPressed: null, child: Text('Save Changes')),
          ],
        ),
      ),
    );
  }
}
