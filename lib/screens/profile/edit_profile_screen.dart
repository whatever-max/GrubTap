import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _username, _firstName, _lastName, _phone;
  File? _pickedImage;
  bool _loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _pickedImage = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _loading = true);

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser!;
    String? avatarUrl = user.userMetadata?['avatar_url'];

    if (_pickedImage != null) {
      final fileExt = _pickedImage!.path.split('.').last;
      final filePath = 'avatars/${user.id}.$fileExt';
      await supabase.storage.from('public').upload(filePath, _pickedImage!);
      avatarUrl = supabase.storage.from('public').getPublicUrl(filePath);
    }

    await supabase.from('users').update({
      'username': _username,
      'first_name': _firstName,
      'last_name': _lastName,
      'phone': _phone,
      'avatar_url': avatarUrl,
    }).eq('id', user.id);

    await supabase.auth.updateUser(UserAttributes(data: {
      'username': _username,
      'avatar_url': avatarUrl,
    }));

    setState(() => _loading = false);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser!;
    final meta = user.userMetadata!;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: CircleAvatar(
                    radius: 50,
                    backgroundImage: _pickedImage != null
                        ? FileImage(_pickedImage!)
                        : (meta['avatar_url'] != null
                        ? NetworkImage(meta['avatar_url'])
                        : const AssetImage('assets/images/default_avatar.png'))
                    as ImageProvider,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: meta['username'],
                decoration: const InputDecoration(labelText: 'Username'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
                onSaved: (v) => _username = v,
              ),
              TextFormField(
                initialValue: meta['first_name'],
                decoration: const InputDecoration(labelText: 'First Name'),
                onSaved: (v) => _firstName = v,
              ),
              TextFormField(
                initialValue: meta['last_name'],
                decoration: const InputDecoration(labelText: 'Last Name'),
                onSaved: (v) => _lastName = v,
              ),
              TextFormField(
                initialValue: meta['phone'],
                decoration: const InputDecoration(labelText: 'Phone Number'),
                onSaved: (v) => _phone = v,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
